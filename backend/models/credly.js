const mongoose = require('mongoose');

const credlySchema = new mongoose.Schema({
    firstname: { type: String, required: false },
    lastname: { type: String, required: false },
    username: { type: String, required: false },
    link: { type: String, required: false },
    issuer_name: { type: String, required: false },
    cert_name: { type: String, required: false },
    issue_date: { type: String, required: false },
});

module.exports = mongoose.model('Credly', credlySchema);
