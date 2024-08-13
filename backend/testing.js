const axios = require('axios');

async function addMentees() {

    try {
        const response = await axios.post('http://localhost:8000/postpermission', {
            headers: {
                'Content-Type': 'application/json',
            },
            body: json.encode({
                'Token' : "6c84fd5d-13bc-4e22-b168-d235e91a3c9b",
                'username': "Sonal Jain",
              })
        });

        const data = response;
        console.log('Extracted Data:', data);

        // Example: Save to database
        // Implement your logic to save data to the database here

    } catch (error) {
        console.error('Error uploading file:', error);
    }
}

// Example call
addMentees();
