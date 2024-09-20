const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
    firstname: { type: String, required: false },
    lastname: { type: String, required: false },
    username: { type: String, required: false }, 
    password: { type: String, required: false }, 
    email: { type: String, required: false },
    user_type: { type: String, required: false },
    phone_number: { type: String, required: false },
    dob: { type: Date, required: false }, 
    github: { type: String, required: false },
    website: { type: String, required: false },
    bio: { type: String, required: false }, 
    college: { type: String, required: false },
    academic_year: { type: String, required: false },
    semester: { type: String, required: false }, 
    cgpa: { type: Number, required: false }, 
    hobby: { type: String, required: false },
});

module.exports = mongoose.model('User', userSchema);

