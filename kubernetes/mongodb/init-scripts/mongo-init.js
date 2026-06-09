// NOTE: This script does NOT execute when MongoDB is started with --replSet flag.
// MongoDB only runs init scripts from /docker-entrypoint-initdb.d/ in standalone mode.
// Data initialization is handled by job-init-replica.yaml instead.

db = db.getSiblingDB('hoteldb');
db.createCollection('reservations');
db.createCollection("hotels")

db.hotels.insertMany([
      { hotel_id: "1", hotel_name: "Hilton", description: "Hilton the best", location: "Tel Aviv", price_per_night: "700" },
      { hotel_id: "2", hotel_name: "Leonardo", description: "Leonardo the best", location: "Dead Sea", price_per_night: "800" },
      { hotel_id: "3", hotel_name: "Caesar Premier Eilat", description: "Caesar Premier Eilat the best", location: "Eilat", price_per_night: "900" }
    ]);    

db.reservations.insertOne({reservation_id: "1",full_name: "John Smite",email_address: "JohnSmite@domain.com",checkIn_date: "02/06/2026",checkOut_date: "10/06/2026",hotel_id: "1"});






