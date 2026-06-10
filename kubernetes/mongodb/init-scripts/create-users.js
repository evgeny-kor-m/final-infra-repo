// create users manually (MONGO_INITDB doesn't work with --replSet)

db.getSiblingDB('admin').createUser({
  user: 'admin',
  pwd: 'passw',
  roles: [{role: 'root', db: 'admin'}]
});
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

print('Users created successfully!');