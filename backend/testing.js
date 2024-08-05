const axios = require('axios');
const FormData = require('form-data');
const fs = require('fs');

async function addMentees(userUsername, filename, batchname, selection) {
    const form = new FormData();
    form.append('file', fs.createReadStream(filename));
    form.append('selection', selection);

    try {
        const response = await axios.post('http://localhost:5000/upload', form, {
            headers: {
                ...form.getHeaders(),
            },
        });

        const data = response.data.data;
        console.log('Extracted Data:', data);

        // Example: Save to database
        // Implement your logic to save data to the database here

    } catch (error) {
        console.error('Error uploading file:', error);
    }
}

// Example call
addMentees('mentor123', 'C:/Users/abc/Downloads/b1.pdf', 'BE A', 'name');
