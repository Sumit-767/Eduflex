const mongoose = require('mongoose');
const { type } = require('os');
const { Interface } = require('readline');

const porfileSchema = new mongoose.Schema({
    fullname: {type:String, required: false},
    username: { type: String, required: false },
    postID: {type: String , required: false, unique: true},
    file: {type: String, required: false},
    post_type: {type: String , required: false},
    post_desc: {type: String, required: false},
    post_likes: {type: Number , required: false},
    interface: {type: String, required: false}
});

module.exports = mongoose.model('Profiles', porfileSchema);