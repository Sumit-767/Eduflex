document.addEventListener('DOMContentLoaded', () => {
    const form = document.querySelector('form');

    form.addEventListener('submit', async (event) => {
        event.preventDefault(); // Prevent the default form submission

        const formData = new FormData(form);
        const tempdata = {};

        formData.forEach((value, key) => {
            tempdata[key] = value;
        });

        const interfaceData = {
            interface: "Webapp", // Replace with your webapp name or identifier
        };

        const data = { ...tempdata, ...interfaceData };

        try {
            const response = await fetch('http://localhost:8000/register', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(data),
            });

            const result = await response.json();

            if (response.ok) {
                alert(result.message); // User registered successfully
                window.location.href = './login.html'; // Redirect to login page
            } else {
                alert(result.message); // Display error message
            }
        } catch (error) {
            console.error('Error:', error);
            alert('An error occurred while registering. Please try again.');
        }
    });
});
