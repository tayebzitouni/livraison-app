type Role = 'client' | 'courier' | 'restaurant' | 'supermarket' | 'admin';
type User = {
  id: string;
  email: string;
  full_name: string;
  role: Role;
  business_name: string | null;
  phone: string | null;
  address: string;
  avatar_url: string | null;
  active: number;
};
type Order = {
  id: string;
  code: string;
  customer_id: string;
  merchant_id: string;
  courier_id: string | null;
  status: string;
  food_total: number;
  delivery_fee: number;
  commission_amount: number;
  client_confirmed_at: string | null;
};
type ProductRow = {
  id: string;
  owner_id: string;
  retail_price: number;
  wholesale_price: number;
  kind: string;
};

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'Content-Type, Authorization, X-File-Name, X-Admin-Setup-Token, Range',
  'Access-Control-Allow-Methods': 'GET, POST, PATCH, OPTIONS',
  'Access-Control-Expose-Headers': 'Content-Length, Content-Range, ETag',
};
const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
  });
const uid = () => crypto.randomUUID();
const hex = (value: Uint8Array) =>
  [...value].map((byte) => byte.toString(16).padStart(2, '0')).join('');
const bytes = (value: string) =>
  new Uint8Array(value.match(/.{2}/g)?.map((part) => parseInt(part, 16)) ?? []);

async function legacyHash(value: string) {
  return hex(
    new Uint8Array(
      await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value)),
    ),
  );
}

async function passwordHash(value: string) {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(value),
    'PBKDF2',
    false,
    ['deriveBits'],
  );
  const result = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', salt, iterations: 120000, hash: 'SHA-256' },
    key,
    256,
  );
  return `pbkdf2$120000$${hex(salt)}$${hex(new Uint8Array(result))}`;
}

async function verifyPassword(value: string, stored: string) {
  if (!stored.startsWith('pbkdf2$')) return (await legacyHash(value)) === stored;
  const [, iterations, salt, expected] = stored.split('$');
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(value),
    'PBKDF2',
    false,
    ['deriveBits'],
  );
  const result = new Uint8Array(
    await crypto.subtle.deriveBits(
      {
        name: 'PBKDF2',
        salt: bytes(salt),
        iterations: Number(iterations),
        hash: 'SHA-256',
      },
      key,
      256,
    ),
  );
  const target = bytes(expected);
  if (result.length !== target.length) return false;
  let difference = 0;
  for (let index = 0; index < result.length; index++) {
    difference |= result[index] ^ target[index];
  }
  return difference === 0;
}

async function sessionUser(request: Request, env: Env): Promise<User | null> {
  const token = request.headers.get('Authorization')?.replace(/^Bearer\s+/i, '');
  if (!token) return null;
  return env.DB.prepare(
    `SELECT u.id,u.email,u.full_name,u.role,u.business_name,u.phone,
      u.address,u.avatar_url,u.active
     FROM sessions s JOIN users u ON u.id=s.user_id
     WHERE s.token=? AND s.expires_at>CURRENT_TIMESTAMP AND u.active=1`,
  )
    .bind(token)
    .first<User>();
}

function publicUser(user: User) {
  return {
    id: user.id,
    email: user.email,
    name: user.full_name,
    role: user.role,
    business_name: user.business_name,
    phone: user.phone,
    address: user.address,
    avatar_url: user.avatar_url,
  };
}

function notification(
  env: Env,
  recipientId: string,
  title: string,
  message: string,
  type: string,
  orderId: string | null,
  eventKey: string,
) {
  return env.DB.prepare(
    `INSERT OR IGNORE INTO notifications
      (id,recipient_id,title,message,type,order_id,event_key)
     VALUES(?,?,?,?,?,?,?)`,
  ).bind(uid(), recipientId, title, message, type, orderId, eventKey);
}

function roleNotification(
  env: Env,
  role: Role,
  title: string,
  message: string,
  type: string,
  orderId: string | null,
  eventKey: string,
) {
  return env.DB.prepare(
    `INSERT OR IGNORE INTO notifications
      (id,recipient_id,title,message,type,order_id,event_key)
     SELECT lower(hex(randomblob(16))),id,?,?,?,?,? FROM users
     WHERE role=? AND active=1`,
  ).bind(title, message, type, orderId, eventKey, role);
}

function normalizedMediaPath(value: unknown, origin: string): string | null {
  if (typeof value !== 'string' || value.length === 0) return null;
  try {
    const media = new URL(value, origin);
    if (media.origin !== origin || !media.pathname.startsWith('/api/media/uploads/')) {
      return null;
    }
    return media.pathname;
  } catch {
    return null;
  }
}

async function serveMedia(request: Request, env: Env, url: URL) {
  const key = decodeURIComponent(url.pathname.slice('/api/media/'.length));
  if (!key.startsWith('uploads/') || key.includes('..')) {
    return json({ error: 'invalid_media_key' }, 400);
  }
  const rangeHeader = request.headers.get('Range');
  const object = await env.MEDIA.get(
    key,
    rangeHeader ? { range: request.headers } : undefined,
  );
  if (!object) return json({ error: 'media_not_found' }, 404);
  const headers = new Headers(cors);
  object.writeHttpMetadata(headers);
  headers.set('ETag', object.httpEtag);
  headers.set('Accept-Ranges', 'bytes');
  headers.set('Cache-Control', 'public, max-age=31536000, immutable');
  let status = 200;
  if (rangeHeader && object.range) {
    status = 206;
    const range = object.range;
    const start = 'suffix' in range
      ? Math.max(0, object.size - range.suffix)
      : (range.offset ?? 0);
    const length = 'length' in range
      ? (range.length ?? object.size - start)
      : object.size - start;
    headers.set('Content-Range', `bytes ${start}-${start + length - 1}/${object.size}`);
    headers.set('Content-Length', String(length));
  } else {
    headers.set('Content-Length', String(object.size));
  }
  return new Response(request.method === 'HEAD' ? null : object.body, {
    status,
    headers,
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === 'OPTIONS') return new Response(null, { headers: cors });
    const url = new URL(request.url);
    try {
      if (url.pathname === '/api/health') {
        return json({ ok: true, service: env.APP_NAME, now: new Date().toISOString() });
      }
      if (url.pathname === '/api/settings' && request.method === 'GET') {
        return json(await env.DB.prepare('SELECT commission_percent,delivery_fee FROM platform_settings WHERE id=1').first());
      }
      if (
        url.pathname.startsWith('/api/media/') &&
        (request.method === 'GET' || request.method === 'HEAD')
      ) {
        return serveMedia(request, env, url);
      }
      if (url.pathname === '/api/auth/signup' && request.method === 'POST') {
        return json({ error: 'admin_managed_accounts' }, 403);
      }
      if (url.pathname === '/api/auth/login' && request.method === 'POST') {
        const body = await request.json<{ email?: string; password?: string }>();
        const user = await env.DB.prepare(
          `SELECT id,email,password_hash,full_name,role,business_name,phone,
            address,avatar_url,active FROM users WHERE email=?`,
        )
          .bind(body.email?.trim().toLowerCase() ?? '')
          .first<User & { password_hash: string }>();
        if (!user || !user.active || !(await verifyPassword(body.password ?? '', user.password_hash))) {
          return json({ error: 'invalid_credentials' }, 401);
        }
        const token = uid();
        await env.DB.prepare(
          "INSERT INTO sessions(token,user_id,expires_at) VALUES(?,?,datetime('now','+30 days'))",
        )
          .bind(token, user.id)
          .run();
        return json({ token, user: publicUser(user) });
      }
      if (url.pathname === '/api/admin/bootstrap' && request.method === 'POST') {
        const setupToken = (env as Env & { ADMIN_SETUP_TOKEN?: string }).ADMIN_SETUP_TOKEN;
        if (!setupToken || request.headers.get('X-Admin-Setup-Token') !== setupToken) {
          return json({ error: 'forbidden' }, 403);
        }
        const existing = await env.DB.prepare("SELECT id FROM users WHERE role='admin' LIMIT 1").first();
        if (existing) return json({ error: 'admin_exists' }, 409);
        const body = await request.json<{ name?: string; email?: string; password?: string }>();
        const name = body.name?.trim() ?? '';
        const email = body.email?.trim().toLowerCase() ?? '';
        if (name.length < 2 || !email.includes('@') || (body.password?.length ?? 0) < 12) {
          return json({ error: 'invalid_admin' }, 400);
        }
        try {
          await env.DB.prepare('INSERT INTO users(id,email,password_hash,full_name,role) VALUES(?,?,?,?,?)')
            .bind(uid(), email, await passwordHash(body.password!), name, 'admin').run();
        } catch { return json({ error: 'email_exists' }, 409); }
        return json({ ok: true }, 201);
      }

      const current = await sessionUser(request, env);
      if (!current) return json({ error: 'unauthorized' }, 401);

      if (url.pathname === '/api/users' && request.method === 'POST') {
        if (current.role !== 'admin') return json({ error: 'admin_only' }, 403);
        const body = await request.json<{
          name?: string;
          email?: string;
          password?: string;
          role?: Role;
          businessName?: string;
          phone?: string;
        }>();
        const name = body.name?.trim() ?? '';
        const email = body.email?.trim().toLowerCase() ?? '';
        const password = body.password ?? '';
        const role = body.role;
        if (
          name.length < 2 ||
          !email.includes('@') ||
          password.length < 8 ||
          !['courier', 'restaurant', 'supermarket'].includes(role ?? '') ||
          (['restaurant', 'supermarket'].includes(role!) && !body.businessName?.trim())
        ) {
          return json({ error: 'invalid_account' }, 400);
        }
        const userId = uid();
        try {
          await env.DB.batch([
            env.DB.prepare(
              `INSERT INTO users
                (id,email,password_hash,full_name,role,business_name,phone)
               VALUES(?,?,?,?,?,?,?)`,
            ).bind(
              userId,
              email,
              await passwordHash(password),
              name,
              role,
              body.businessName?.trim() || null,
              body.phone?.trim() || null,
            ),
            notification(
              env,
              userId,
              'Bienvenue sur Wasla',
              'Votre compte a été créé par l’administrateur.',
              'account',
              null,
              `account:${userId}:created`,
            ),
          ]);
        } catch {
          return json({ error: 'email_exists' }, 409);
        }
        return json({ ok: true, id: userId }, 201);
      }

      if (url.pathname === '/api/settings' && request.method === 'PATCH') {
        if (current.role !== 'admin') return json({ error: 'admin_only' }, 403);
        const body = await request.json<{ commissionPercent?: number; deliveryFee?: number }>();
        if (!Number.isInteger(body.commissionPercent) || body.commissionPercent! < 0 || body.commissionPercent! > 100 ||
            !Number.isInteger(body.deliveryFee) || body.deliveryFee! < 0) {
          return json({ error: 'invalid_settings' }, 400);
        }
        await env.DB.prepare('UPDATE platform_settings SET commission_percent=?,delivery_fee=? WHERE id=1')
          .bind(body.commissionPercent, body.deliveryFee).run();
        return json({ commission_percent: body.commissionPercent, delivery_fee: body.deliveryFee });
      }

      if (url.pathname === '/api/auth/logout' && request.method === 'POST') {
        const token = request.headers.get('Authorization')?.replace(/^Bearer\s+/i, '');
        if (token) await env.DB.prepare('DELETE FROM sessions WHERE token=?').bind(token).run();
        return json({ ok: true });
      }

      if (url.pathname === '/api/profile' && request.method === 'PATCH') {
        const body = await request.json<{
          name?: string;
          email?: string;
          phone?: string;
          address?: string;
          businessName?: string | null;
          avatarUrl?: string | null;
        }>();
        const name = body.name?.trim() ?? '';
        const email = body.email?.trim().toLowerCase() ?? '';
        const businessName = body.businessName?.trim() || null;
        if (name.length < 2 || !email.includes('@')) {
          return json({ error: 'invalid_profile' }, 400);
        }
        if (['restaurant', 'supermarket'].includes(current.role) && !businessName) {
          return json({ error: 'business_name_required' }, 400);
        }
        const avatarUrl = body.avatarUrl
          ? normalizedMediaPath(body.avatarUrl, url.origin)
          : null;
        if (body.avatarUrl && !avatarUrl) return json({ error: 'invalid_avatar' }, 400);
        try {
          await env.DB.prepare(
            `UPDATE users SET full_name=?,email=?,phone=?,address=?,business_name=?,
              avatar_url=? WHERE id=?`,
          )
            .bind(
              name,
              email,
              body.phone?.trim() ?? '',
              body.address?.trim() ?? '',
              businessName,
              avatarUrl,
              current.id,
            )
            .run();
        } catch {
          return json({ error: 'email_exists' }, 409);
        }
        return json({ ok: true });
      }

      if (url.pathname === '/api/media' && request.method === 'POST') {
        const contentType = request.headers.get('Content-Type')?.split(';')[0] ?? '';
        const extensions: Record<string, string> = {
          'image/jpeg': 'jpg',
          'image/png': 'png',
          'image/webp': 'webp',
          'image/gif': 'gif',
          'video/mp4': 'mp4',
          'video/webm': 'webm',
          'video/quicktime': 'mov',
        };
        const extension = extensions[contentType];
        if (!extension) return json({ error: 'unsupported_media' }, 415);
        const video = contentType.startsWith('video/');
        if (video && !['restaurant', 'supermarket'].includes(current.role)) {
          return json({ error: 'video_forbidden' }, 403);
        }
        const maxBytes = video ? 25 * 1024 * 1024 : 8 * 1024 * 1024;
        const declaredLength = Number(request.headers.get('Content-Length') ?? 0);
        if (declaredLength < 1 || declaredLength > maxBytes) {
          return json({ error: 'media_too_large' }, 413);
        }
        const data = await request.arrayBuffer();
        if (data.byteLength < 1 || data.byteLength > maxBytes) {
          return json({ error: 'media_too_large' }, 413);
        }
        const key = `uploads/${current.id}/${uid()}.${extension}`;
        await env.MEDIA.put(key, data, {
          httpMetadata: {
            contentType,
            cacheControl: 'public, max-age=31536000, immutable',
          },
          customMetadata: {
            uploadedBy: current.id,
            originalName: (request.headers.get('X-File-Name') ?? 'media').slice(0, 120),
          },
        });
        return json({ url: `/api/media/${key}`, type: video ? 'video' : 'image' }, 201);
      }

      if (url.pathname === '/api/categories' && request.method === 'GET') {
        const where = current.role === 'admin' ? '' : 'WHERE active=1';
        return json(
          await env.DB.prepare(
            `SELECT id,name,kind,active,sort_order FROM categories ${where}
             ORDER BY kind,sort_order,name`,
          ).all(),
        );
      }
      if (url.pathname === '/api/categories' && request.method === 'POST') {
        if (current.role !== 'admin') return json({ error: 'admin_only' }, 403);
        const body = await request.json<{ name?: string; kind?: string }>();
        const name = body.name?.trim() ?? '';
        if (name.length < 2 || !['meal', 'grocery'].includes(body.kind ?? '')) {
          return json({ error: 'invalid_category' }, 400);
        }
        const categoryId = uid();
        try {
          await env.DB.prepare(
            'INSERT INTO categories(id,name,kind,created_by) VALUES(?,?,?,?)',
          )
            .bind(categoryId, name, body.kind, current.id)
            .run();
        } catch {
          return json({ error: 'category_exists' }, 409);
        }
        return json({ id: categoryId }, 201);
      }
      const categoryActive = url.pathname.match(/^\/api\/categories\/([^/]+)\/active$/);
      if (categoryActive && request.method === 'PATCH') {
        if (current.role !== 'admin') return json({ error: 'admin_only' }, 403);
        const body = await request.json<{ active?: boolean }>();
        if (typeof body.active !== 'boolean') return json({ error: 'invalid_active' }, 400);
        const result = await env.DB.prepare('UPDATE categories SET active=? WHERE id=?')
          .bind(body.active ? 1 : 0, decodeURIComponent(categoryActive[1]))
          .run();
        return result.meta.changes === 1
          ? json({ ok: true })
          : json({ error: 'not_found' }, 404);
      }

      if (url.pathname === '/api/products' && request.method === 'GET') {
        const visibility = current.role === 'admin' ? '' : current.role === 'restaurant' || current.role === 'supermarket'
          ? 'AND ((p.active=1 AND p.approval_status=\'approved\') OR p.owner_id=?)'
          : "AND p.active=1 AND p.approval_status='approved'";
        return json(
          await env.DB.prepare(
            `SELECT p.*,u.business_name FROM products p JOIN users u ON u.id=p.owner_id
             WHERE 1=1 ${current.role === 'admin' ? '' : 'AND u.active=1'} ${visibility} ORDER BY p.created_at DESC`,
          ).bind(...(current.role === 'restaurant' || current.role === 'supermarket' ? [current.id] : [])).all(),
        );
      }
      if (url.pathname === '/api/products' && request.method === 'POST') {
        if (!['restaurant', 'supermarket'].includes(current.role)) {
          return json({ error: 'merchant_only' }, 403);
        }
        const body = await request.json<{
          name?: string;
          description?: string;
          kind?: string;
          category?: string;
          retailPrice?: number;
          wholesalePrice?: number;
          emoji?: string;
          mediaUrl?: string;
          mediaType?: string;
          ingredients?: string;
          allergens?: string;
          preparationMinutes?: number;
          calories?: number | null;
        }>();
        const expected = current.role === 'supermarket' ? 'grocery' : 'meal';
        if (body.kind !== expected) return json({ error: 'product_kind_forbidden' }, 403);
        const mediaUrl = normalizedMediaPath(body.mediaUrl, url.origin);
        const validPrices = Number.isInteger(body.wholesalePrice) && body.wholesalePrice! > 0;
        const validDetails =
          (body.description?.trim().length ?? 0) >= 10 &&
          Number.isInteger(body.preparationMinutes) &&
          body.preparationMinutes! >= 1 &&
          body.preparationMinutes! <= 240;
        if (
          !body.name?.trim() ||
          !body.category?.trim() ||
          !validPrices ||
          !validDetails ||
          !mediaUrl ||
          !['image', 'video'].includes(body.mediaType ?? '')
        ) {
          return json({ error: 'invalid_product' }, 400);
        }
        const category = await env.DB.prepare(
          'SELECT id FROM categories WHERE name=? AND kind=? AND active=1',
        )
          .bind(body.category.trim(), expected)
          .first<{ id: string }>();
        if (!category) return json({ error: 'invalid_category' }, 400);
        const productId = uid();
        await env.DB.prepare(
          `INSERT INTO products
            (id,owner_id,name,description,kind,category,retail_price,wholesale_price,
             emoji,media_url,media_type,ingredients,allergens,preparation_minutes,calories,active,approval_status)
           VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
        )
          .bind(
            productId,
            current.id,
            body.name.trim(),
            body.description!.trim(),
            expected,
            body.category.trim(),
            body.wholesalePrice,
            body.wholesalePrice,
            body.emoji?.trim() || '🍽️',
            mediaUrl,
            body.mediaType,
            body.ingredients?.trim() ?? '',
            body.allergens?.trim() ?? '',
            body.preparationMinutes,
            body.calories ?? null,
            0,
            'pending',
          )
          .run();
        await roleNotification(
          env,
          'admin',
          'Nouveau produit',
          `${current.business_name ?? current.full_name} a publié ${body.name.trim()}.`,
          'catalog',
          null,
          `product:${productId}`,
        ).run();
        return json({ id: productId }, 201);
      }
      const productApprove = url.pathname.match(/^\/api\/products\/([^/]+)\/approval$/);
      if (productApprove && request.method === 'PATCH') {
        if (current.role !== 'admin') return json({ error: 'admin_only' }, 403);
        const body = await request.json<{ status?: string; retailPrice?: number }>();
        const productId = decodeURIComponent(productApprove[1]);
        const product = await env.DB.prepare('SELECT owner_id,wholesale_price FROM products WHERE id=?')
          .bind(productId).first<{owner_id:string; wholesale_price:number}>();
        if (!product) return json({ error: 'not_found' }, 404);
        if (!['approved','rejected'].includes(body.status ?? '') ||
            (body.status === 'approved' && (!Number.isInteger(body.retailPrice) || body.retailPrice! < product.wholesale_price))) {
          return json({ error: 'invalid_approval' }, 400);
        }
        await env.DB.batch([
          env.DB.prepare('UPDATE products SET approval_status=?,retail_price=?,active=? WHERE id=?')
            .bind(body.status, body.status === 'approved' ? body.retailPrice : product.wholesale_price, body.status === 'approved' ? 1 : 0, productId),
          notification(env, product.owner_id, body.status === 'approved' ? 'Produit approuvé' : 'Produit refusé',
            body.status === 'approved' ? 'Votre produit est visible par les clients.' : 'Votre produit doit être corrigé.',
            'catalog', null, `product:${productId}:${body.status}`),
        ]);
        return json({ ok: true });
      }
      const productActive = url.pathname.match(/^\/api\/products\/([^/]+)\/active$/);
      if (productActive && request.method === 'PATCH') {
        const body = await request.json<{ active?: boolean }>();
        if (typeof body.active !== 'boolean') return json({ error: 'invalid_active' }, 400);
        const productId = decodeURIComponent(productActive[1]);
        const product = await env.DB.prepare('SELECT owner_id,approval_status FROM products WHERE id=?')
          .bind(productId)
          .first<{ owner_id: string; approval_status: string }>();
        if (!product) return json({ error: 'not_found' }, 404);
        if (current.role !== 'admin' && product.owner_id !== current.id) {
          return json({ error: 'forbidden' }, 403);
        }
        if (product.approval_status !== 'approved') return json({ error: 'approval_required' }, 409);
        await env.DB.prepare('UPDATE products SET active=? WHERE id=?')
          .bind(body.active ? 1 : 0, productId)
          .run();
        return json({ ok: true });
      }

      if (url.pathname === '/api/notifications' && request.method === 'GET') {
        return json(
          await env.DB.prepare(
            `SELECT id,title,message,type,order_id,is_read AS read,created_at
             FROM notifications WHERE recipient_id=?
             ORDER BY created_at DESC LIMIT 100`,
          )
            .bind(current.id)
            .all(),
        );
      }
      if (url.pathname === '/api/notifications/read-all' && request.method === 'PATCH') {
        await env.DB.prepare('UPDATE notifications SET is_read=1 WHERE recipient_id=?')
          .bind(current.id)
          .run();
        return json({ ok: true });
      }
      const notificationRead = url.pathname.match(/^\/api\/notifications\/([^/]+)\/read$/);
      if (notificationRead && request.method === 'PATCH') {
        const result = await env.DB.prepare(
          'UPDATE notifications SET is_read=1 WHERE id=? AND recipient_id=?',
        )
          .bind(decodeURIComponent(notificationRead[1]), current.id)
          .run();
        return result.meta.changes === 1
          ? json({ ok: true })
          : json({ error: 'not_found' }, 404);
      }

      if (url.pathname === '/api/orders' && request.method === 'GET') {
        let where = 'o.customer_id=?';
        let args: unknown[] = [current.id];
        if (current.role === 'courier') {
          where = "o.courier_id=? OR (o.courier_id IS NULL AND o.status='placed')";
        }
        if (current.role === 'restaurant' || current.role === 'supermarket') {
          where = "o.merchant_id=? AND o.status<>'placed'";
        }
        if (current.role === 'admin') {
          where = '1=1';
          args = [];
        }
        const orders = await env.DB.prepare(
          `SELECT o.*,c.full_name customer_name,
            COALESCE(m.business_name,m.full_name) merchant_name,d.full_name courier_name
           FROM orders o JOIN users c ON c.id=o.customer_id
           JOIN users m ON m.id=o.merchant_id LEFT JOIN users d ON d.id=o.courier_id
           WHERE ${where} ORDER BY o.created_at DESC`,
        )
          .bind(...args)
          .all<Record<string, unknown>>();
        if (!orders.results.length) return json({ results: [] });
        const orderIds = orders.results.map((order) => order.id as string);
        const marks = orderIds.map(() => '?').join(',');
        const items = await env.DB.prepare(
          `SELECT oi.order_id,oi.product_id,oi.quantity,oi.retail_unit_price,
            oi.wholesale_unit_price,p.name product_name,p.description,p.emoji,p.kind,
            p.category,p.media_url,p.media_type,p.ingredients,p.allergens,
            p.preparation_minutes,p.calories
           FROM order_items oi JOIN products p ON p.id=oi.product_id
           WHERE oi.order_id IN (${marks}) ORDER BY oi.rowid`,
        )
          .bind(...orderIds)
          .all<Record<string, unknown>>();
        return json({
          results: orders.results.map((order) => ({
            ...order,
            items: items.results.filter((item) => item.order_id === order.id),
          })),
        });
      }
      if (url.pathname === '/api/orders' && request.method === 'POST') {
        if (current.role !== 'client') return json({ error: 'client_only' }, 403);
        const body = await request.json<{
          items?: { productId: string; quantity: number }[];
          address?: string;
          paymentMethod?: string;
          note?: string;
        }>();
        if (
          !body.items?.length ||
          !body.address?.trim() ||
          body.items.some(
            (item) =>
              !item.productId ||
              !Number.isInteger(item.quantity) ||
              item.quantity < 1 ||
              item.quantity > 99,
          )
        ) {
          return json({ error: 'invalid_order' }, 400);
        }
        if (
          typeof body.note !== 'undefined' &&
          (typeof body.note !== 'string' || body.note.length > 500)
        ) {
          return json({ error: 'invalid_note' }, 400);
        }
        const ids = body.items.map((item) => item.productId);
        const placeholders = ids.map(() => '?').join(',');
        const found = await env.DB.prepare(
          `SELECT id,owner_id,retail_price,wholesale_price,kind FROM products
           WHERE active=1 AND approval_status='approved' AND id IN (${placeholders})`,
        )
          .bind(...ids)
          .all<ProductRow>();
        const products = new Map(found.results.map((product) => [product.id, product]));
        if (products.size !== new Set(ids).size) {
          return json({ error: 'product_not_found' }, 400);
        }
        const merchants = new Set(found.results.map((product) => product.owner_id));
        if (merchants.size !== 1) return json({ error: 'single_merchant_required' }, 400);
        const foodTotal = body.items.reduce(
          (sum, item) => sum + products.get(item.productId)!.retail_price * item.quantity,
          0,
        );
        const settings = await env.DB.prepare('SELECT commission_percent,delivery_fee FROM platform_settings WHERE id=1')
          .first<{ commission_percent: number; delivery_fee: number }>();
        if (!settings) return json({ error: 'settings_missing' }, 500);
        const commissionAmount = Math.round(foodTotal * settings.commission_percent / 100);
        const orderId = uid();
        const code = `WS-${Date.now().toString().slice(-7)}`;
        const merchantId = found.results[0].owner_id;
        await env.DB.batch([
          env.DB.prepare(
            `INSERT INTO orders
              (id,code,customer_id,merchant_id,status,food_total,delivery_fee,commission_percent,commission_amount,address,customer_note,payment_method,payment_status)
             VALUES(?,?,?,?,'placed',?,?,?,?,?,?,?,?)`,
          ).bind(
            orderId,
            code,
            current.id,
            merchantId,
            foodTotal,
            settings.delivery_fee,
            settings.commission_percent,
            commissionAmount,
            body.address.trim(),
            body.note?.trim() ?? '',
            body.paymentMethod ?? 'cash',
            body.paymentMethod === 'Carte' ? 'paid' : 'pending',
          ),
          ...body.items.map((item) => {
            const product = products.get(item.productId)!;
            return env.DB.prepare(
              `INSERT INTO order_items
                (id,order_id,product_id,quantity,retail_unit_price,wholesale_unit_price)
               VALUES(?,?,?,?,?,?)`,
            ).bind(
              uid(),
              orderId,
              item.productId,
              item.quantity,
              product.retail_price,
              product.wholesale_price,
            );
          }),
          roleNotification(
            env,
            'courier',
            'Nouvelle livraison disponible',
            `Commande ${code} · ${foodTotal + settings.delivery_fee} DA`,
            'order',
            orderId,
            `order:${orderId}:placed`,
          ),
          roleNotification(
            env,
            'admin',
            'Nouvelle commande',
            `${code} vient d’être créée.`,
            'order',
            orderId,
            `order:${orderId}:admin-placed`,
          ),
        ]);
        return json({ id: orderId, code, status: 'placed', total: foodTotal + settings.delivery_fee }, 201);
      }

      const statusMatch = url.pathname.match(/^\/api\/orders\/([^/]+)\/status$/);
      if (statusMatch && request.method === 'POST') {
        const code = decodeURIComponent(statusMatch[1]).replace(/^#/, '');
        const order = await env.DB.prepare(
          `SELECT id,code,customer_id,merchant_id,courier_id,status,food_total,
            delivery_fee,commission_amount,client_confirmed_at FROM orders WHERE code=? OR code=?`,
        )
          .bind(code, `#${code}`)
          .first<Order>();
        if (!order) return json({ error: 'not_found' }, 404);
        const body = await request.json<{ status?: string }>();
        let allowed = false;
        let assign = false;
        if (
          current.role === 'courier' &&
          order.status === 'placed' &&
          body.status === 'courier_validated' &&
          !order.courier_id
        ) {
          allowed = true;
          assign = true;
        }
        if (
          (current.role === 'restaurant' || current.role === 'supermarket') &&
          current.id === order.merchant_id
        ) {
          const next: Record<string, string> = {
            courier_validated: 'merchant_accepted',
            merchant_accepted: 'preparing',
            preparing: 'ready',
          };
          allowed = next[order.status] === body.status;
        }
        if (current.role === 'courier' && current.id === order.courier_id) {
          const next: Record<string, string> = {
            ready: 'picked_up',
            picked_up: 'delivered',
          };
          allowed = next[order.status] === body.status;
        }
        if (!allowed) return json({ error: 'invalid_transition' }, 409);
        const update = env.DB.prepare(
          `UPDATE orders SET status=?,courier_id=CASE WHEN ? THEN ? ELSE courier_id END
           WHERE id=? AND status=?`,
        ).bind(body.status, assign ? 1 : 0, current.id, order.id, order.status);
        const statements: D1PreparedStatement[] = [update];
        const courierId = assign ? current.id : order.courier_id;
        const label: Record<string, string> = {
          courier_validated: 'Un livreur a accepté votre commande.',
          merchant_accepted: 'Le commerce a accepté votre commande.',
          preparing: 'Votre commande est en préparation.',
          ready: 'Votre commande est prête à être récupérée.',
          picked_up: 'Votre commande est en route.',
          delivered: 'Le livreur indique avoir livré. Confirmez la réception.',
        };
        statements.push(
          notification(
            env,
            order.customer_id,
            body.status === 'delivered' ? 'Confirmez votre livraison' : 'Commande mise à jour',
            label[body.status ?? ''] ?? 'Le statut de votre commande a changé.',
            'order',
            order.id,
            `order:${order.id}:${body.status}:client`,
          ),
        );
        if (body.status === 'courier_validated') {
          statements.push(
            notification(
              env,
              order.merchant_id,
              'Nouvelle commande à accepter',
              `${order.code} a été validée par un livreur.`,
              'order',
              order.id,
              `order:${order.id}:courier_validated:merchant`,
            ),
          );
        } else if (courierId && ['merchant_accepted', 'preparing', 'ready'].includes(body.status ?? '')) {
          statements.push(
            notification(
              env,
              courierId,
              'Commande mise à jour',
              `${order.code} · ${label[body.status ?? '']}`,
              'order',
              order.id,
              `order:${order.id}:${body.status}:courier`,
            ),
          );
        }
        if (body.status === 'delivered') {
          statements.push(
            notification(
              env,
              order.merchant_id,
              'Livraison annoncée',
              `${order.code} attend la confirmation du client.`,
              'order',
              order.id,
              `order:${order.id}:delivered:merchant`,
            ),
          );
        }
        const results = await env.DB.batch(statements);
        if (results[0].meta.changes !== 1) return json({ error: 'order_changed' }, 409);
        return json({ ok: true, code: order.code, status: body.status });
      }

      const confirmMatch = url.pathname.match(/^\/api\/orders\/([^/]+)\/confirm-delivery$/);
      if (confirmMatch && request.method === 'POST') {
        if (current.role !== 'client') return json({ error: 'client_only' }, 403);
        const code = decodeURIComponent(confirmMatch[1]).replace(/^#/, '');
        const order = await env.DB.prepare(
          `SELECT id,code,customer_id,merchant_id,courier_id,status,food_total,
            delivery_fee,commission_amount,client_confirmed_at FROM orders WHERE code=? OR code=?`,
        )
          .bind(code, `#${code}`)
          .first<Order>();
        if (
          !order ||
          order.customer_id !== current.id ||
          order.status !== 'delivered' ||
          order.client_confirmed_at
        ) {
          return json({ error: 'invalid_confirmation' }, 409);
        }
        const admin = await env.DB.prepare(
          "SELECT id FROM users WHERE role='admin' AND active=1 LIMIT 1",
        ).first<{ id: string }>();
        if (!order.courier_id) return json({ error: 'invalid_order' }, 409);
        const statements: D1PreparedStatement[] = [
          env.DB.prepare(
            `UPDATE orders SET client_confirmed_at=CURRENT_TIMESTAMP,payment_status='paid'
             WHERE id=? AND status='delivered' AND client_confirmed_at IS NULL`,
          ).bind(order.id),
          env.DB.prepare(
            `INSERT OR IGNORE INTO wallet_entries
              (id,owner_id,order_id,entry_type,amount) VALUES(?,?,?,?,?)`,
          ).bind(uid(), order.merchant_id, order.id, 'sale', order.food_total - order.commission_amount),
          env.DB.prepare(
            `INSERT OR IGNORE INTO wallet_entries
              (id,owner_id,order_id,entry_type,amount) VALUES(?,?,?,?,?)`,
          ).bind(uid(), order.courier_id, order.id, 'delivery_fee', order.delivery_fee),
          notification(
            env,
            order.merchant_id,
            'Livraison confirmée',
            `Le client a confirmé la réception de ${order.code}.`,
            'payment',
            order.id,
            `order:${order.id}:confirmed:merchant`,
          ),
          notification(
            env,
            order.courier_id,
            'Livraison confirmée',
            `Votre gain de ${order.delivery_fee} DA est disponible.`,
            'payment',
            order.id,
            `order:${order.id}:confirmed:courier`,
          ),
        ];
        if (admin) {
          statements.push(
            env.DB.prepare(
              `INSERT OR IGNORE INTO wallet_entries
                (id,owner_id,order_id,entry_type,amount) VALUES(?,?,?,?,?)`,
            ).bind(uid(), admin.id, order.id, 'commission', order.commission_amount),
            notification(
              env,
              admin.id,
              'Commande terminée',
              `${order.code} a été confirmée par le client.`,
              'payment',
              order.id,
              `order:${order.id}:confirmed:admin`,
            ),
          );
        }
        const results = await env.DB.batch(statements);
        if (results[0].meta.changes !== 1) return json({ error: 'order_changed' }, 409);
        return json({ ok: true, code: order.code, status: 'client_confirmed' });
      }

      if (url.pathname === '/api/users' && request.method === 'GET') {
        if (current.role !== 'admin') return json({ error: 'admin_only' }, 403);
        return json(
          await env.DB.prepare(
            `SELECT id,email,full_name,role,business_name,phone,address,avatar_url,
              active,created_at FROM users ORDER BY created_at DESC`,
          ).all(),
        );
      }
      const userActive = url.pathname.match(/^\/api\/users\/([^/]+)\/active$/);
      if (userActive && request.method === 'PATCH') {
        if (current.role !== 'admin') return json({ error: 'admin_only' }, 403);
        const body = await request.json<{ active?: boolean }>();
        const userId = decodeURIComponent(userActive[1]);
        if (typeof body.active !== 'boolean' || userId === current.id) {
          return json({ error: 'invalid_active' }, 400);
        }
        const result = await env.DB.prepare(
          "UPDATE users SET active=? WHERE id=? AND role<>'admin'",
        )
          .bind(body.active ? 1 : 0, userId)
          .run();
        return result.meta.changes === 1
          ? json({ ok: true })
          : json({ error: 'not_found' }, 404);
      }

      if (url.pathname === '/api/withdrawals' && request.method === 'POST') {
        if (!['courier', 'restaurant', 'supermarket'].includes(current.role)) {
          return json({ error: 'withdrawal_forbidden' }, 403);
        }
        const body = await request.json<{ amount?: number }>();
        const amount = body.amount;
        if (!Number.isInteger(amount) || !amount || amount < 1) {
          return json({ error: 'invalid_withdrawal' }, 400);
        }
        const withdrawalId = uid();
        const results = await env.DB.batch([
          env.DB.prepare(
            `INSERT INTO withdrawal_requests(id,owner_id,amount,status)
             SELECT ?,?,?,'pending' WHERE
             (SELECT COALESCE(SUM(amount),0) FROM wallet_entries WHERE owner_id=?)>=?`,
          ).bind(withdrawalId, current.id, amount, current.id, amount),
          env.DB.prepare(
            `INSERT INTO wallet_entries(id,owner_id,entry_type,amount)
             SELECT ?,?,'withdrawal_pending',? WHERE
             EXISTS(SELECT 1 FROM withdrawal_requests WHERE id=?)`,
          ).bind(uid(), current.id, -amount, withdrawalId),
          roleNotification(
            env,
            'admin',
            'Nouvelle demande de retrait',
            `${current.business_name ?? current.full_name} demande ${amount} DA.`,
            'payment',
            null,
            `withdrawal:${withdrawalId}`,
          ),
        ]);
        if (results[0].meta.changes !== 1) {
          return json({ error: 'invalid_withdrawal' }, 400);
        }
        return json({ id: withdrawalId, status: 'pending', amount }, 201);
      }
      if (url.pathname === '/api/wallet' && request.method === 'GET') {
        const owner = url.searchParams.get('owner');
        if (current.role === 'admin' && owner === 'all') {
          return json(await env.DB.prepare('SELECT * FROM wallet_entries ORDER BY created_at DESC').all());
        }
        const ownerId = current.role === 'admin' && owner ? owner : current.id;
        return json(
          await env.DB.prepare(
            'SELECT * FROM wallet_entries WHERE owner_id=? ORDER BY created_at DESC',
          )
            .bind(ownerId)
            .all(),
        );
      }
      return json({ error: 'not_found' }, 404);
    } catch (error) {
      console.error(
        JSON.stringify({
          event: 'request_error',
          path: url.pathname,
          error: error instanceof Error ? error.message : String(error),
        }),
      );
      return json({ error: 'server_error' }, 500);
    }
  },
} satisfies ExportedHandler<Env>;
