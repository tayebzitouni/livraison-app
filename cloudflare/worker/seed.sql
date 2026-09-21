INSERT OR IGNORE INTO users(id,email,password_hash,full_name,role,business_name) VALUES
 ('demo-client','client@wasla.dz','588c55f3ce2b8569b153c5abbf13f9f74308b88a20017cc699b835cc93195d16','Sofia Benali','client',NULL),
 ('u-courier','livreur@wasla.dz','588c55f3ce2b8569b153c5abbf13f9f74308b88a20017cc699b835cc93195d16','Yacine Amari','courier',NULL),
 ('demo-restaurant','restaurant@wasla.dz','588c55f3ce2b8569b153c5abbf13f9f74308b88a20017cc699b835cc93195d16','Maya Chen','restaurant','Maison Sage'),
 ('u-supermarket','superette@wasla.dz','588c55f3ce2b8569b153c5abbf13f9f74308b88a20017cc699b835cc93195d16','Nora James','supermarket','Marché Quotidien');
INSERT OR IGNORE INTO products(id,owner_id,name,description,kind,category,retail_price,wholesale_price,emoji) VALUES
 ('demo-bowl-poulet','demo-restaurant','Bowl poulet du jardin','Poulet aux herbes, quinoa et houmous','meal','Healthy',1490,820,'🥗'),
 ('demo-pates-champignons','demo-restaurant','Pâtes aux champignons','Crème, parmesan et champignons rôtis','meal','Pâtes',1650,910,'🍝'),
 ('demo-avocats-bio','u-supermarket','Pack avocats bio','Quatre avocats mûrs','grocery','Frais',640,390,'🥑'),
 ('demo-pain-artisanal','u-supermarket','Pain artisanal','Pain au levain du jour','grocery','Boulangerie',480,260,'🍞');
INSERT OR IGNORE INTO categories(id,name,kind,sort_order) VALUES
 ('cat-healthy','Healthy','meal',10),
 ('cat-pasta','Pâtes','meal',20),
 ('cat-burgers','Burgers','meal',30),
 ('cat-pizza','Pizza','meal',40),
 ('cat-desserts','Desserts','meal',50),
 ('cat-fresh','Frais','grocery',10),
 ('cat-bakery','Boulangerie','grocery',20),
 ('cat-drinks','Boissons','grocery',30),
 ('cat-home','Maison','grocery',40);
