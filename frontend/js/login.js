document.addEventListener("DOMContentLoaded", () => {
    const form = document.querySelector(".login100-form");

    form.addEventListener("submit", async (event) => {
        event.preventDefault(); // Prevent the default form submission

        // Check server status
        try {
            const pingResponse = await fetch("http://localhost:8000/ping");
            const pingResult = await pingResponse.json();

            if (pingResponse.ok) {
                console.log(pingResult.message); // "Server is up and running"
                
                // Proceed with login request
                const formData = new FormData(form);
                const data = {};
                formData.forEach((value, key) => {
                    data[key] = value;
                });

                const interfaceData = {
                    interface: "Webapp", // Replace with your webapp name or identifier
                };
                
                const payload = { ...data, ...interfaceData };

                try {
                    const response = await fetch("http://localhost:8000/login", {
                        method: "POST",
                        headers: {
                            "Content-Type": "application/json"
                        },
                        body: JSON.stringify(payload),
                    });

                    const result = await response.json();

                    if (response.ok) {
                        alert("Login successful");
                        // Redirect to the dashboard page
                        window.location.href = "./dashboard.html";
                    } else {
                        alert(result.message || "Login failed");
                        // Handle unsuccessful login
                    }
                } catch (error) {
                    console.error("Error during login:", error);
                    alert("An error occurred during login");
                }

            } else {
                alert("Server is not reachable");
                // Handle server not reachable
            }
        } catch (error) {
            console.error("Error checking server status:", error);
            alert("Unable to reach server");
            // Handle network or server error
        }
    });
});
