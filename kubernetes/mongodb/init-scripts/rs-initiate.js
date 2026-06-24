// initialize Replica Set from inside the pod (localhost exception works here)

try {
    rs.initiate({
    _id: 'rs0',
    members: [
        {_id: 0, host: 'mongodb-0.mongodb-headless.database.svc.cluster.local:27017'},
        {_id: 1, host: 'mongodb-1.mongodb-headless.database.svc.cluster.local:27017'},
        {_id: 2, host: 'mongodb-2.mongodb-headless.database.svc.cluster.local:27017'} ]
    }) 
    print('rs initialized successfully!');
} 
catch(e) {
    print('rs already initialized, skipping: ' + e.message);
}