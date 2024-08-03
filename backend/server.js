const express = require("express");
const https = require("http");
const fs = require("fs");
const mongoose = require("mongoose");
const path = require("path");
const bodyParser = require('body-parser');
const axios = require("axios");
const cookieParser = require("cookie-parser");
const readline = require("readline");
const jwt = require("jsonwebtoken");
const { v4: uuidv4, stringify } = require("uuid");
const { format } = require('date-fns');
const multer = require("multer");
require("dotenv").config();
const cors = require("cors");
const CSRFToken = require("./models/csrfttoken");
const User = require("./models/users");
const Profiles = require("./models/profiles");
const Credly = require("./models/credly");


const serverSK = process.env.SERVER_SEC_KEY;

const server = express();
server.use(cookieParser());
server.use(bodyParser.json());

// Use CORS middleware
server.use(cors({
    origin: '*', // an coming request
    methods: ['GET', 'POST'],
    allowedHeaders: ['Content-Type', 'Authorization']
}));


mongoose.connect("mongodb://127.0.0.1/RMS");

const logDirectory = path.join(__dirname, 'logs');

// Create the logs directory if it doesn't exist
if (!fs.existsSync(logDirectory)) {
    fs.mkdirSync(logDirectory);
}

const getLogFileName = () => {
    const dateStr = format(new Date(), 'yyyy-MM-dd');
    return path.join(logDirectory, `${dateStr}.log`);
};

const logMessage = (message) => {
    const logFile = getLogFileName();
    const timestamp = new Date().toISOString();
    const logEntry = `[${timestamp}] ${message}\n`;

    // Ensure the log file is created if it doesn't exist
    fs.open(logFile, 'a', (err, fd) => {
        if (err) {
            throw err;
        }

        fs.appendFile(fd, logEntry, (err) => {
            if (err) throw err;
            fs.close(fd, (err) => {
                if (err) throw err;
            });
        });
    });
};

server.set("view engine", "hbs");
server.set("views", __dirname + "/views");
server.use("/scripts", express.static(__dirname + "/public/scripts"));
const directoryPath = path.join(__dirname, "uploads");

server.use(express.urlencoded({ extended: true }));
server.use(express.json());
server.use(express.static(path.join(__dirname, "public")));
server.use(express.static("public"));

const storage = multer.diskStorage({
    destination: (req, file, callback) =>
    {
        const uploadDir = `uploads/${req.body.up_username}`;
        fs.mkdirSync(uploadDir, { recursive: true });
        callback(null, uploadDir);
    },
    filename: (req,file,callback)=>{
        console.log("filename");
        callback(null, req.body.up_username + "-" + file.originalname );
    }
});

const upload  = multer({ storage : storage});


server.get("/ping", (req, res) => {
    res.status(200).json({ message: "Server is up and running" });
});

server.post("/mobiletoken", async(req,res) => {
    const response = await axios.get('https://api.ipify.org?format=json');
    const userIP = response.data.ip;
    
    const { mobiletoken } = req.body;
    try
    {
        const mobile_token_check = await CSRFToken.findOne({ token : mobiletoken});
        const tokenAge = (Date.now() - mobile_token_check.createdAt) / (1000*60*60*24);
        if(tokenAge > 30)
        {
            logMessage(`[=] Mobileapp ${userIP} : Token for user ${mobile_token_check.username} has expired`);
            await CSRFToken.deleteOne({ token : mobile_token_check.token});
            return res.status(400).json({message : "expired"}); 
        }
        else if(!mobile_token_check)
        {
            return res.status(401).json({message : "No token found"});
        }
        else{
            logMessage(`[=] Mobileapp ${userIP} : Token for user ${mobile_token_check.username} is valid`);
            return res.status(200).json({ message : "valid" });
        }
    }
    catch (e)
    {
        logMessage(`[*] Mobile token checking error ${e}`);
        return res.status(200).json({ message : "Internal Server Error"});
    }
});


server.post("/login", async (req, res) => {
    const response = await axios.get('https://api.ipify.org?format=json');
    const userIP = response.data.ip;
    const { userUsername, userPwd , interface} = req.body;
    console.log( " API " , interface);
    logMessage(`[=] User ${userUsername} attempting to log in`);

    try {
        const user = await User.findOne({ username: userUsername });

        if (!user || user.password !== userPwd) {
            logMessage(`[-] ${interface} ${userIP} : Unsuccessful login attempt for user ${userUsername}`);
            return res.status(401).json({ message: "Invalid username or password" });
        }

        logMessage(`[=] ${interface} ${userIP} : User ${userUsername} successfully logged in`);

        const uniqueId = uuidv4();
        const payload = jwt.sign({ userId: uniqueId }, serverSK, { expiresIn: "15m" });

        const check_token_DB = await CSRFToken.findOne({ username: userUsername });
        if (check_token_DB) {
            await CSRFToken.deleteOne({ username: userUsername });
        }
        
        if(interface == "Webapp")
        {
            logMessage(`[=] ${interface} ${userIP} : Token provided for user ${userUsername}`);
            const token_Data = new CSRFToken({
                token: uniqueId,
                username: userUsername,
                interface: "Webapp"
            });
            await token_Data.save();
            res.cookie("Token", payload, {
                httpOnly: true,
                secure: process.env.NODE_ENV === 'production', // Set to true if serving over HTTPS
                maxAge: 15 * 60 * 1000 // 15 minutes
            });
            return res.status(200).json({ message: "Login successful" });
        }
        else if(interface == "Mobileapp")
        {
            logMessage(`[=] ${interface} ${userIP} : Token provided for user ${userUsername}`);
            const LLT = uuidv4();
            const token_Data = new CSRFToken({
                token: LLT,
                username: userUsername,
                interface: "Mobileapp"
            });
            await token_Data.save();
            return res.status(200).json({ message: "Login successfull", token : LLT , userType : user.user_type})
        }

    
    } catch (error) {
        logMessage("[*] Database connection failed: " + error.message);
        return res.status(500).json({ message: "Internal Server Error" });
    }
});

server.post("/register", async (req, res) => {
    const response = await axios.get('https://api.ipify.org?format=json');
    const userIP = response.data.ip;
    const credlylink_template = "https://www.credly.com/users/"
    
    const { firstname , lastname, email , ph_no , reguserUsername, reguserPwd, confuserPwd,credlylink, interface } = req.body;
    const specialCharRegex = /[!@#\$%\^&\*\(\)_\-=+]/;
    const passwordMinLength = 8;

    if (reguserPwd.length < passwordMinLength) {
        return res.status(400).json({message :"Password should be at least 8 characters long."});
    }
    if (reguserPwd !== confuserPwd) {
        return res.status(400).json({message : "Passwords do not match."});
    }
        
    try {
        if (credlylink.toLowerCase().includes(firstname.toLowerCase()) && 
            credlylink.toLowerCase().includes(lastname.toLowerCase()) &&
            credlylink.toLowerCase().includes(credlylink_template)) {

            const response = await axios.get('http://localhost:5000/fetch-badges', {
                params: { url: credlylink }
            });

            // Handle the response data
            console.log('Badges data:', response.data);

            const badgeDataArray = response.data;

            // Insert each badge data into the database
            for (const badge of badgeDataArray) {
                try {
                    const newBadge = new Credly({
                        firstname: firstname,
                        lastname: lastname,
                        link: credlylink,
                        issuer_name: badge.issuer_name,
                        cert_name: badge.certificate_name,
                        issue_date: badge.issued_date
                    });

                    await newBadge.save();
                } catch (error) {
                    console.error("badges error : "+error)
                }
            }          
        } else {
            res.status(400).json({ message: 'Invalid credlylink' });
        }
    } catch (error) {
        logMessage(`[*] ${interface} ${userIP} : Error fetching badges `);
        res.status(500).json({ message: 'Failed to fetch and save badges data' });
    }
    

    const existingUser = await User.findOne({ username: reguserUsername });
    if (!existingUser) {
        try {
            const newUser = new User({
                firstname : firstname,
                lastname : lastname,
                username : reguserUsername,
                password: reguserPwd,
                user_type: "Student",
                email : email,
                phone_number: ph_no
            });
            await newUser.save();
            logMessage(`[=] ${interface} ${userIP} : New student registered: ${reguserUsername}`);
            return res.status(201).json({ message: "User registered successfully" });
        } catch (error) {
            logMessage(`[*] ${interface} ${userIP} : New student registration failed: ${error.message} `);
            return res.status(500).json({message: "User registration failed"});
        }
    } else {
        return res.status(400).json({message : "Username already exists "});
    }
});

server.post("/changeprofile", async (req, res) => {
    const response = await axios.get('https://api.ipify.org?format=json');
    const userIP = response.data.ip;
    
    const { Token, changeemail, changepwd, changephoneno, interface } = req.body;
    console.log("Token:", Token, "Email:", changeemail, "Password:", changepwd, "PhoneNo:", changephoneno);

    // Check if the token is provided
    if (Token) {
        const tokencheck = await CSRFToken.findOne({ token: Token });

        // Validate token
        if (!tokencheck || tokencheck.token !== Token) {
            logMessage(`[-] ${interface} ${userIP} : Invalid token provided for changing user data. Token: ${Token}`);
            return res.status(400).json({ message: "Invalid token" });
        }
    }
    const tokencheck = await CSRFToken.findOne({ token: Token });

    // Email format validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (changeemail && !emailRegex.test(changeemail)) {
        logMessage(`[-] ${interface} ${userIP} : Failed to update profile. Invalid email format. Token: ${Token}`);
        return res.status(400).json({ message: "Invalid email format." });
    }

    // Password strength validation
    const passwordRegex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[\W_]).{8,}$/;
    if (changepwd && !passwordRegex.test(changepwd)) {
        logMessage(`[-] ${interface} ${userIP} : Failed to update profile. Weak password. Token: ${Token}`);
        return res.status(400).json({
            message: "Password must be at least 8 characters long, and contain at least one symbol, one uppercase letter, one lowercase letter, and one number."
        });
    }

    // Phone number length validation
    const phoneRegex = /^\d{10,11}$/;
    if (changephoneno && !phoneRegex.test(changephoneno)) {
        logMessage(`[-] ${interface} ${userIP} : Failed to update profile. Invalid phone number. Token: ${Token}`);
        return res.status(400).json({ message: "Invalid phone number." });
    }

    // If all validations pass
    try {
        // Update the user data
        await User.updateOne(
            { username: tokencheck.username },
            {
                $set: {
                    password: changepwd,
                    email: changeemail,
                    phone_number: changephoneno
                }
            },
            { upsert: true }
        );

        // Delete the used token
        await CSRFToken.deleteOne({ token: Token });

        return res.status(200).json({ message: "Update successful." });

    } catch (e) {
        logMessage(`[*] Internal server error: ${e}`);
        return res.status(500).json({ message: "Internal server error" });
    }
});


server.post('/upload', upload.single('file'), async (req, res) => {
    try {
        const response = await axios.get('https://api.ipify.org?format=json');
        const userIP = response.data.ip;

        const { Token,up_username, post_type, post_desc,filename, interface } = req.body;

        const tokencheck = CSRFToken.findOne({token : Token});
        let fullname
        if (up_username == tokencheck.username)
        {
            username_data = User.findOne({ username : up_username })
            fullname = username_data.fullname; 
        }

        const newpost = new Profiles({
            fullname: String(fullname),
            username: String(up_username),
            postID: String(up_username +'-'+ uuidv4()), // Ensure the concatenation is a string
            file: String(`uploads/${up_username}/${up_username}-${filename}`),
            post_type: String(post_type),
            post_desc: String(post_desc),
            post_likes: Number(0), // Keep this as a number
            interface: String(interface),
        });
        newpost.save();     
        logMessage(`[=] ${interface} ${userIP} : Posted a file ${up_username}-${filename}`);
        res.status(200).json({message : "Uploaded Successfully"});


    } catch (error) {
        const response = await axios.get('https://api.ipify.org?format=json');
        const userIP = response.data.ip;
        const { filename, up_username ,interface} = req.body;
        const og_filepath = `uploads/${up_username}/${up_username}-${filename}`

        // Construct the file path
        const filePath = path.join(__dirname, og_filepath);
    
        // Attempt to delete the file
        fs.unlink(filePath, (err) => {
            if (err) {
                logMessage(`[*] ${interface} ${userIP} : Failed to delete file: ${err}`);
            } else {
                logMessage(`[*] ${interface} ${userIP} : File deleted successfully: ${filePath}`);
            }
        });
    
        console.error(`[*] Internal server error: ${error}`);
        res.status(500).json({ message: "Internal server error" });
    }
});

server.get("/myprofile", async(req,res)=> {
    const response = await axios.get('https://api.ipify.org?format=json');
    const userIP = response.data.ip;
    
    const {Token, interface} = req.body;
    console.log(Token, interface);
    const tokencheck = CSRFToken.findOne({token : Token});
    console.log(tokencheck)
    if(tokencheck)
    {
        try {
            console.log(tokencheck.username);
            user_profile_data = await Profiles.find({ username : tokencheck.username});
            logMessage(`[=] ${interface} ${userIP} : ${tokencheck.username} pulled their own profile`);
            res.status(200).json({ data : user_profile_data});
        } catch (error) {
            logMessage(`[*] ${interface} ${userIP} : Internal server error ${error}`);
            res.status(500).json({message : "Internal server error"});
        }
    }

});


server.listen(8000, () => {
    console.log(`http://localhost:8000`);
  })
