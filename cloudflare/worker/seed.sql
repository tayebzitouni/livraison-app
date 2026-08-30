INSERT OR IGNORE INTO users (id,email,password_hash,full_name,role) VALUES
 ('u-client','1','6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b','فتحي بوعلام','client'),
 ('u-driver','2','d4735e3a265e16eee03f59718b9b5d03019c07d8b6c51f90da3a666eec13ab35','سائق وصلة','driver'),
 ('u-restaurant','3','4e07408562bedb8b60ce05c1decfe3ad16b72230967de01f640b7e4729b49fce','مطبخ أم خديجة','restaurant'),
 ('u-supplier','4','4b227777d4dd1fc61c6f884f48641d02b4d121d3fd328cb08b5531fcacdabf8a','مورد وصلة','supplier'),
 ('u-admin','5','ef2d127de37b942baad06145e54b0c619a1f22327b2ebbcfbec78f5564afe39d','إدارة وصلة','admin');
INSERT OR IGNORE INTO products (id,owner_id,name,description,retail_price,wholesale_price,emoji) VALUES
 ('tajine-olive','u-restaurant','طاجين زيتون بالدجاج','طبق فردي محضر اليوم',800,640,'🍲'),
 ('bourek-meat','u-restaurant','بوراك باللحم (3 حبات)','مقرمش ولذيذ',300,240,'🥟'),
 ('matlou3','u-restaurant','مطلوع الدار','خبز تقليدي طازج',50,40,'🫓'),
 ('chorba','u-restaurant','شربة فريك','وصفة جداتنا',250,200,'🍜');
