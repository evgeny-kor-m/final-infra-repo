db.createCollection("reservations", {
    validator: {
        $jsonSchema: {
            bsonType: "object",
            required: ["reservation_id", "full_name", "email_address", 
                       "checkIn_date", "checkOut_date", "hotel_id"],
            properties: {
                reservation_id: {
                    bsonType: "int",
                    description: "must, not null"
                },
                full_name: {
                    bsonType: "string",
                    description: "must, not null"
                },
                email_address: {
                    bsonType: "string",
                    description: "must, not null"
                },
                checkIn_date: {
                    bsonType: "string",
                    description: "must, not null"
                },
                checkOut_date: {
                    bsonType: "string",
                    description: "must, not null"
                },
                hotel_id: {
                    bsonType: "int",
                    description: "must, not null"
                }
            }
        }
    }
})
