interface Env { DB: D1Database; APP_NAME: string; }
type User = { id: string; email: string; full_name: string; role: string };

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'Content-Type, Authorization', 'Access-Control-Allow-Methods': 'GET,POST,OPTIONS' };
const json = (data: unknown, status = 200) => new Response(JSON.stringify(data), { status, headers: { ...cors, 'Content-Type': 'application/json' } });
const id = () => crypto.randomUUID();
async function hash(value: string) { const bytes = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value)); return [...new Uint8Array(bytes)].map((b) => b.toString(16).padStart(2, '0')).join(''); }

async function auth(request: Request, env: Env): Promise<User | null> {
  const token = request.headers.get('Authorization')?.replace(/^Bearer\s+/i, '');
  if (!token) return null;
  return await env.DB.prepare('SELECT u.id,u.email,u.full_name,u.role FROM sessions s JOIN users u ON u.id=s.user_id WHERE s.token=? AND s.expires_at > CURRENT_TIMESTAMP').bind(token).first<User>();
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === 'OPTIONS') return new Response(null, { headers: cors });
    const url = new URL(request.url);
    try {
      if (url.pathname === '/api/health') return json({ ok: true, service: env.APP_NAME });
      if (url.pathname === '/api/auth/login' && request.method === 'POST') {
        const body = await request.json<{ email?: string; password?: string }>();
        const user = await env.DB.prepare('SELECT * FROM users WHERE email=?').bind(body.email ?? '').first<any>();
        if (!user || user.password_hash !== await hash(body.password ?? '')) return json({ error: 'invalid_credentials' }, 401);
        const token = id();
        await env.DB.prepare("INSERT INTO sessions(token,user_id,expires_at) VALUES(?,?,datetime('now','+30 days'))").bind(token, user.id).run();
        return json({ token, user: { id: user.id, email: user.email, name: user.full_name, role: user.role } });
      }
      if (url.pathname === '/api/products' && request.method === 'GET') return json(await env.DB.prepare('SELECT id,name,description,retail_price AS price,emoji FROM products WHERE active=1 ORDER BY created_at DESC').all());
      const user = await auth(request, env);
      if (!user) return json({ error: 'unauthorized' }, 401);
      if (url.pathname === '/api/auth/logout' && request.method === 'POST') { const token = request.headers.get('Authorization')?.replace(/^Bearer\s+/i, ''); if (token) await env.DB.prepare('DELETE FROM sessions WHERE token=?').bind(token).run(); return json({ ok: true }); }
      if (url.pathname === '/api/orders' && request.method === 'GET') {
        const query = user.role === 'driver' ? 'SELECT o.*,u.full_name AS customer_name FROM orders o JOIN users u ON u.id=o.customer_id WHERE o.driver_id=? OR (o.driver_id IS NULL AND o.status=\'draft\') ORDER BY o.created_at DESC' : user.role === 'admin' ? 'SELECT * FROM orders ORDER BY created_at DESC' : 'SELECT * FROM orders WHERE customer_id=? ORDER BY created_at DESC';
        const args = user.role === 'admin' ? [] : [user.id];
        return json(await env.DB.prepare(query).bind(...args).all());
      }
      if (url.pathname === '/api/orders' && request.method === 'POST') {
        if (user.role !== 'client') return json({ error: 'client_only' }, 403);
        const body = await request.json<{ items: { productId: string; quantity: number }[]; phone?: string }>();
        if (!body.items?.length) return json({ error: 'items_required' }, 400);
        if (body.items.some((item) => !item.productId || !Number.isInteger(item.quantity) || item.quantity < 1 || item.quantity > 99)) return json({ error: 'invalid_items' }, 400);
        const products = await env.DB.prepare(`SELECT id,retail_price,wholesale_price FROM products WHERE active=1 AND id IN (${body.items.map(() => '?').join(',')})`).bind(...body.items.map((x) => x.productId)).all<any>();
        const byId = new Map(products.results.map((p) => [p.id, p]));
        if (byId.size !== new Set(body.items.map((item) => item.productId)).size) return json({ error: 'product_not_found' }, 400);
        const foodTotal = body.items.reduce((sum, item) => sum + ((byId.get(item.productId)?.retail_price ?? 0) * item.quantity), 0);
        const code = `TJ-${Date.now().toString().slice(-6)}`; const orderId = id();
        const statements = [env.DB.prepare('INSERT INTO orders(id,code,customer_id,status,food_total,phone) VALUES(?,?,?,\'draft\',?,?)').bind(orderId, code, user.id, foodTotal, body.phone ?? null), ...body.items.map((item) => { const p = byId.get(item.productId); return env.DB.prepare('INSERT INTO order_items(id,order_id,product_id,quantity,retail_unit_price,wholesale_unit_price) VALUES(?,?,?,?,?,?)').bind(id(), orderId, item.productId, item.quantity, p.retail_price, p.wholesale_price); })];
        await env.DB.batch(statements); return json({ code, status: 'draft', total: foodTotal + 200 }, 201);
      }
      const match = url.pathname.match(/^\/api\/orders\/([^/]+)\/status$/);
      if (match && request.method === 'POST') {
        if (!['driver', 'admin', 'restaurant', 'supplier'].includes(user.role)) return json({ error: 'forbidden' }, 403);
        const body = await request.json<{ status: string }>(); const order = await env.DB.prepare('SELECT * FROM orders WHERE code=?').bind(match[1]).first<any>();
        if (!order) return json({ error: 'not_found' }, 404);
        const allowed = ['draft', 'confirmed', 'picked_up', 'delivered']; if (!allowed.includes(body.status)) return json({ error: 'invalid_status' }, 400);
        await env.DB.prepare('UPDATE orders SET status=?, driver_id=COALESCE(driver_id,?) WHERE code=?').bind(body.status, user.role === 'driver' ? user.id : null, match[1]).run();
        if (body.status === 'delivered') {
          const admin = await env.DB.prepare("SELECT id FROM users WHERE role='admin' LIMIT 1").first<{id: string}>();
          const items = await env.DB.prepare('SELECT oi.*,p.owner_id FROM order_items oi JOIN products p ON p.id=oi.product_id WHERE oi.order_id=?').bind(order.id).all<any>();
          const statements = items.results.filter((x) => x.owner_id).map((x) => env.DB.prepare("INSERT OR IGNORE INTO wallet_entries(id,owner_id,order_id,entry_type,amount) VALUES(?,?,?,?,?)").bind(id(), x.owner_id, order.id, 'sale', Math.round(x.retail_unit_price * x.quantity * .8)));
          if (admin) statements.push(env.DB.prepare("INSERT OR IGNORE INTO wallet_entries(id,owner_id,order_id,entry_type,amount) VALUES(?,?,?,?,?)").bind(id(), admin.id, order.id, 'commission', Math.round(order.food_total * .2)));
          const driverId = user.role === 'driver' ? user.id : order.driver_id; if (driverId) statements.push(env.DB.prepare("INSERT OR IGNORE INTO wallet_entries(id,owner_id,order_id,entry_type,amount) VALUES(?,?,?,?,?)").bind(id(), driverId, order.id, 'delivery_fee', order.delivery_fee));
          if (statements.length) await env.DB.batch(statements);
        }
        return json({ ok: true, code: match[1], status: body.status });
      }
      if (url.pathname === '/api/wallet' && request.method === 'GET') return json(await env.DB.prepare('SELECT * FROM wallet_entries WHERE owner_id=? ORDER BY created_at DESC').bind(user.id).all());
      return json({ error: 'not_found' }, 404);
    } catch (error) { return json({ error: 'server_error', detail: String(error) }, 500); }
  },
};
