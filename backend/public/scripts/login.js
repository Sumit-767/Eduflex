
  console.log("Login script is loaded");

  document.getElementById('login-form').addEventListener('submit', async function(event) {
    event.preventDefault(); // Prevent default form submission

    const username = document.getElementById('username').value;
    const password = document.getElementById('password').value;

    try {
      const response = await fetch('https://nice-genuinely-pug.ngrok-free.app/login', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          userUsername: username,
          userPwd: password,
          interface: 'Webapp', // Specify that this is coming from the web app
        }),
      });

      const result = await response.json();

      if (response.status === 200) {
        alert('Login successful');
        window.location.href = 'dashboard.html'; // Redirect to dashboard or appropriate page
      } else {
        alert('Login failed: ' + result.message);
      }
    } catch (error) {
      console.error('Error during login:', error);
      alert('An error occurred during login.');
    }
  });
