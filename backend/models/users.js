const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
    fullname: {type:String, required: false},
    username: { type: String, required: false },
    password: { type: String, required: false },
    email: { type: String, required: false },
    user_type: { type: String, required: false },
    phone_number: {type: String, required: false},
});

module.exports = mongoose.model('User', userSchema);
