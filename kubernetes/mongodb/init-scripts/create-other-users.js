try {
  db.getSiblingDB('admin').createUser({
    user: 'backend_user',
    pwd: 'backend_pass',
    roles: [{ role: 'readWrite', db: 'hoteldb' }]
  });
  db.getSiblingDB('admin').createUser({
    user: 'readonly_user',
    pwd: 'readonly_pass',
    roles: [{ role: 'read', db: 'hoteldb' }]
  });
  db.getSiblingDB("admin").createUser({
  user: "superadmin",
  pwd: "superpassw",
  roles: [{ role: "userAdminAnyDatabase", db: "admin" }, { role: "readWrite", db: "admin" }]
  })
  print('Users created!');
} catch(e) {
  print('Users already exist, skipping: ' + e.message);
}
