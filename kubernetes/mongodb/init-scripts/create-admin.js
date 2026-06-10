// create users manually (MONGO_INITDB doesn't work with --replSet)

try {
  db.getSiblingDB('admin').createUser({
    user: 'admin',
    pwd: 'passw',
    roles: [{role: 'root', db: 'admin'}]
  });
  print('Admin user created!');
} catch(e) {
  print('Admin already exists, skipping: ' + e.message);
}