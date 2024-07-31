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
const CSRFToken = require("./models/csrfttoken");
const User = require("./models/users");
const cors = require("cors");

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

const checkToken = async (req, res, next) => {
    try {
        const token = req.cookies.Token;
        const decode = jwt.verify(token, serverSK);
        const user_token = await CSRFToken.findOne({ token: decode.userId });
        if (!user_token) {
            logMessage("[-] Webapp : No token, redirecting to login");
            return res.status(401).json({ message: "Unauthorized" });
        }
        next();
    } catch (error) {
        logMessage("CHECKTOKEN ERROR: " + error.message);
        return res.status(401).json({ message: "Unauthorized" });
    }
};

server.get("/ping", (req, res) => {
    res.status(200).json({ message: "Server is up and running" });
});

server.get("/dashboard", checkToken, (req, res) => {
    res.send("This is the dashboard");
});

server.post("/login", async (req, res) => {
    const { userUsername, userPwd , interface} = req.body;
    console.log( " API " , interface);
    logMessage(`[=] User ${userUsername} attempting to log in`);

    try {
        const user = await User.findOne({ username: userUsername });

        if (!user || user.password !== userPwd) {
            logMessage(`[-] Unsuccessful login attempt for user ${userUsername}`);
            return res.status(401).json({ message: "Invalid username or password" });
        }

        logMessage(`[=] User ${userUsername} successfully logged in`);

        const uniqueId = uuidv4();
        const payload = jwt.sign({ userId: uniqueId }, serverSK, { expiresIn: "15m" });

        const check_token_DB = await CSRFToken.findOne({ username: userUsername });
        if (check_token_DB) {
            await CSRFToken.deleteOne({ username: userUsername });
        }
        
        if(interface == "Webapp")
        {
            logMessage(`[=] Webapp : Token provided for user ${userUsername}`);
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
            logMessage(`[=] Mobile : Token provided for user ${userUsername}`);
            const LLT = uuidv4();
            const token_Data = new CSRFToken({
                token: LLT,
                username: userUsername,
                interface: "Mobileapp"
            });
            await token_Data.save();
            return res.status(200).json({ message: "Login successfull", token : LLT })
        }

    
    } catch (error) {
        logMessage("[*] Database connection failed: " + error.message);
        return res.status(500).json({ message: "Internal Server Error" });
    }
});


server.post("/register", async (req, res) => {
    const { fullname, email , ph_no , reguserUsername, reguserPwd, confuserPwd } = req.body;
    const specialCharRegex = /[!@#\$%\^&\*\(\)_\-=+]/;
    const passwordMinLength = 8;

    if (reguserPwd.length < passwordMinLength) {
        return res.status(400).json({message :"Password should be at least 8 characters long."});
    }
    if (reguserPwd !== confuserPwd) {
        return res.status(400).json({message : "Passwords do not match."});
    }

    const existingUser = await User.findOne({ username: reguserUsername });
    if (!existingUser) {
        try {
            const newUser = new User({
                username: reguserUsername,
                password: reguserPwd,
                user_type: "Student",
                fullname:fullname,
                email : email,
                phone_number: ph_no
            });
            await newUser.save();
            logMessage(`[=] New student registered: ${reguserUsername}`);
            return res.status(201).json({ message: "User registered successfully" });
        } catch (error) {
            logMessage("[*] New student registration failed: " + error.message);
            return res.status(500).json({message: "User registration failed"});
        }
    } else {
        return res.status(400).json({message : "Username already exists "});
    }
});

server.listen(8000, () => {
    console.log(`http://localhost:8000`);
  })
