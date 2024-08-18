const mongoose = require('mongoose');

const porfileSchema = new mongoose.Schema({
    fisrtname: {type:String, required: false},
    lastname: {type:String, required: false},
    username: { type: String, required: false },
    postID: {type: String , required: false, unique: true},
    file: {type: String, required: false},
    imagePaths: { type: [String], required: false },
    post_type: {type: String , required: false},
    post_desc: {type: String, required: false},
    post_likes: {type: Number , required: false},
    hashtags:{type : [String] , required : false},
    broken_tags: {type: [String] , required: false},
    interface: {type: String, required: false},
    approved : {type: Boolean , required: false},
});

module.exports = mongoose.model('Profiles', porfileSchema);