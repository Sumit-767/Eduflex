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
const FormData = require('form-data');
const multer = require("multer");
require("dotenv").config();
const cors = require("cors");
const pdf = require('pdf-poppler');
const CSRFToken = require("./models/csrfttoken");
const User = require("./models/users");
const Profiles = require("./models/profiles");
const Credly = require("./models/credly");
const Mentor = require("./models/mentees");

const BASE_URL = 'https://nice-genuinely-pug.ngrok-free.app/';
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

async function addMentees(userUsername, filename, batchname, selection,interface,userIP) {
    const form = new FormData();
    const filePath = `C:/Eduflex/backend/uploads/${userUsername}/${filename}`;
    form.append('file', fs.createReadStream(filePath));
    form.append('selection', selection);
    console.log(" here in async function");
    try {
        const form = new FormData();
        const filePath = `C:/Eduflex/backend/uploads/${userUsername}/${filename}`;
        form.append('file', fs.createReadStream(filePath));
        form.append('selection', selection.toLowerCase());

        console.log("Uploading file...");

        const response = await axios.post('http://localhost:5000/upload', form, {
            headers: {
                ...form.getHeaders(),
            },
        });

        const data = response.data.data;
        console.log('Extracted Data:', data);

        const mentorStudents = [];
        const mentorStudentsMoodle = [];

        for (const name of data) {
            const parts = name.split(' ');
            if (parts.length >= 2) {
                const firstname = parts[0].toLowerCase();
                const lastname = parts[1].toLowerCase();
                

                const userExists = await User.findOne({ 
                    $or: [
                        { firstname: new RegExp(`^${firstname}$`, 'i'), lastname: new RegExp(`^${lastname}$`, 'i') },
                        { firstname: new RegExp(`^${lastname}$`, 'i'), lastname: new RegExp(`^${firstname}$`, 'i') }
                    ]
                });

                if (userExists) {
                    mentorStudents.push(name);
                    mentorStudentsMoodle.push(userExists.username);
                }
            }
        }

        if (mentorStudents.length > 0) {
            const existingBatch = await Mentor.findOne({ batch: batchname });

            if (existingBatch) {
                // Append new students to the existing batch
                const uniqueStudents = new Set([...existingBatch.students, ...mentorStudents]);
                existingBatch.students = Array.from(uniqueStudents);
                await existingBatch.save();
                console.log('Mentees updated successfully');
                logMessage(`[=] ${interface} ${userIP} : New mentees existing group under mentor ${userUsername} `) 
            } else {
                // Create a new batch
                const newMentees = new Mentor({
                    mentor: userUsername,
                    students: mentorStudents,
                    username : mentorStudentsMoodle,
                    batch: batchname,
                });
                await newMentees.save();
                console.log('Mentees added successfully');
                logMessage(`[=] ${interface} ${userIP} : New mentees added under mentor ${userUsername} `) 

            }
        }
         else {
            console.log('No valid mentees found');
        }
    } catch (error) {
        console.error('Error processing mentees:', error);
    }
}

async function fetchAndSaveBadges(userUsername) {
    try {
        // Retrieve user data from Credly and User collections
        const mycredly_data = await Credly.findOne({ username: userUsername });
        const db_user = await User.findOne({ username: userUsername });
        const firstname = db_user.firstname;
        const lastname = db_user.lastname;

        if (!mycredly_data) {
            throw new Error('User not found');
        }

        const credlylink = mycredly_data.link;
        const response = await axios.get('http://localhost:5000/fetch-badges', {
            params: { url: credlylink }
        });

        const badgeDataArray = response.data;

        // Fetch existing badges for this user from the database
        const existingBadges = await Credly.find({ username: userUsername });

        // Create a set of existing badge identifiers (e.g., certificate name and issue date)
        const existingBadgeIdentifiers = new Set(
            existingBadges.map(badge => `${badge.cert_name}-${badge.issue_date}`)
        );

        // Prepare an array to hold new badges
        const newBadges = [];

        // Identify new badges
        for (const badge of badgeDataArray) {
            const badgeIdentifier = `${badge.certificate_name}-${badge.issued_date}`;
            if (!existingBadgeIdentifiers.has(badgeIdentifier)) {
                newBadges.push({
                    firstname: firstname,
                    lastname: lastname,
                    username: userUsername,
                    link: credlylink,
                    issuer_name: badge.issuer_name,
                    cert_name: badge.certificate_name,
                    issue_date: badge.issued_date
                });
            }
        }

        // Insert only new badges into the database
        if (newBadges.length > 0) {
            await Credly.insertMany(newBadges);
            
        } else {
            console.log('No new badges to insert.');
        }
    } catch (error) {
        console.error("Error fetching and saving badges:", error);
    }
}


server.set("view engine", "hbs");
server.set("views", __dirname + "/views");
server.use("/scripts", express.static(__dirname + "/public/scripts"));
const directoryPath = path.join(__dirname, "uploads");
server.use('/uploads', express.static(path.join(__dirname, 'uploads')));

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

const hashtag_storage = multer.diskStorage({
    destination: (req,file,callback) =>
    {
        const hashtag_file = `hashtag_extractions/`;
        fs.mkdirSync(hashtag_file, {recursive: true});
        callback(null,hashtag_file);
    },
    filename: (req,file,callback) => 
    {
        callback(null,req.body.up_username+"-"+file.originalname);
    }
});

const extract_hashtag_folder = multer({storage : hashtag_storage});


server.get("/ping", (req, res) => {
    res.status(200).json({ message: "Server is up and running" });
});

server.post("/mobiletoken", async(req,res) => {
    let userIP = req.headers['x-forwarded-for'] || req.socket.remoteAddress;


    if (Array.isArray(userIP)) {
        userIP = userIP[0];
    } else if (userIP.includes(',')) {
        userIP = userIP.split(',')[0].trim();
    }
    
    const { mobiletoken } = req.body;
    console.log(mobiletoken);
    try
    {
        const mobile_token_check = await CSRFToken.findOne({ token : mobiletoken});
        const user = await User.findOne({username : mobile_token_check.username});
        const tokenAge = (Date.now() - mobile_token_check.createdAt) / (1000*60*60*24);
        if(tokenAge > 30)
        {
            console.log("token expired");
            logMessage(`[=] Mobileapp ${userIP} : Token for user ${mobile_token_check.username} has expired`);
            await CSRFToken.deleteOne({ token : mobile_token_check.token});
            return res.status(400).json({message : "expired"}); 
        }
        else if(!mobile_token_check)
        {
            console.log("token not ofund");
            return res.status(401).json({message : "No token found"});
        }
        else{
            fetchAndSaveBadges(mobile_token_check.username);
            logMessage(`[=] Mobileapp ${userIP} : Token for user ${mobile_token_check.username} is valid`);
            console.log("token found");
            return res.status(200).json({ message : "valid" ,user_type : user.user_type });
        }
    }
    catch (e)
    {
        logMessage(`[*] Mobile token checking error ${e}`);
        return res.status(200).json({ message : "Internal Server Error"});
    }
});


server.post("/login", async (req, res) => {
    let userIP = req.headers['x-forwarded-for'] || req.socket.remoteAddress;


    if (Array.isArray(userIP)) {
        userIP = userIP[0];
    } else if (userIP.includes(',')) {
        userIP = userIP.split(',')[0].trim();
    }
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
            fetchAndSaveBadges(userUsername);
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

server.post("/logout", async(req,res)=>{
    const {Token} = req.body;
    console.log("token logged out :" , Token)
    await CSRFToken.deleteOne({ token : Token});
    return res.status(200).json({ message : "Logged out "});
});

server.post("/register", async (req, res) => {
    let userIP = req.headers['x-forwarded-for'] || req.socket.remoteAddress;
    if (Array.isArray(userIP)) {
        userIP = userIP[0];
    } else if (userIP.includes(',')) {
        userIP = userIP.split(',')[0].trim();
    }
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

            // Insert each badge data into the database-+
            for (const badge of badgeDataArray) {
                try {
                    const newBadge = new Credly({
                        firstname: firstname,
                        lastname: lastname,
                        username : reguserUsername,
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

server.post("/changeprofile",async (req, res) => {
    let userIP = req.headers['x-forwarded-for'] || req.socket.remoteAddress;

    if (Array.isArray(userIP)) {
        userIP = userIP[0];
    } else if (userIP.includes(',')) {
        userIP = userIP.split(',')[0].trim();
    }
    
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
        const { Token, up_username, post_type, post_desc, filename, interface } = req.body;
        let { hashtags } = req.body;

        // Handle `hashtags` whether it is a string or an array
        if (typeof hashtags === 'string') {
            hashtags = hashtags.split(',').filter(tag => tag.trim() !== '');
        }

        // Ensure hashtags is an array
        if (!Array.isArray(hashtags)) {
            return res.status(400).json({ message: "Invalid hashtags format" });
        }

        const tokencheck = await CSRFToken.findOne({ token: Token });
        if (!tokencheck || up_username !== tokencheck.username) {
            return res.status(400).json({ message: "Invalid Token or Username" });
        }

        const user_data = await User.findOne({ username: up_username });
        if (!user_data) {
            return res.status(404).json({ message: "User not found" });
        }

        const filePath = `uploads/${up_username}/${up_username}-${filename}`;

        if (post_type === "post") {
            // Convert PDF to images
            const opts = {
                format: 'jpeg',
                out_dir: path.dirname(filePath),
                out_prefix: path.basename(filePath, path.extname(filePath)),
                page: null // Convert all pages
            };

            pdf.convert(filePath, opts)
                .then(async() => {
                    // Rename the files with sequential numbers
                    const renameFiles = (directory, baseName) => {
                        fs.readdir(directory, (err, files) => {
                            if (err) {
                                console.error('Error reading directory:', err);
                                return;
                            }

                            const imageFiles = files.filter(file => file.startsWith(baseName) && file.endsWith('.jpeg'));
                            imageFiles.sort();

                            imageFiles.forEach((file, index) => {
                                const oldPath = path.join(directory, file);
                                const newPath = path.join(directory, `${baseName}-${index + 1}.jpeg`);
                                fs.rename(oldPath, newPath, err => {
                                    if (err) {
                                        console.error('Error renaming file:', err);
                                    } else {
                                        // File renamed successfully
                                    }
                                });
                            });
                        });
                    };

                    renameFiles(opts.out_dir, opts.out_prefix);

                    // Collect paths of image files
                    const uploadDir = path.join(__dirname, `uploads/${up_username}/`);

                    const imagePaths = fs.readdirSync(uploadDir)
                        .filter(file => file.startsWith(opts.out_prefix) && file.endsWith('.jpg'))
                        .map(file => path.join(`uploads/${up_username}/`, file));

                    const cleanedHashtags = hashtags.map(tag => tag
                        .replace(/[^a-zA-Z0-9\s]/g, ' ')  // Replace all non-alphanumeric characters with space
                        .replace(/\s+/g, ' ')  // Replace multiple spaces with a single space
                        .trim()  // Remove leading and trailing spaces
                    );
                    console.log("Cleaned:", cleanedHashtags);
                    const brokenTags = cleanedHashtags.flatMap(tag => tag.split(' ')).filter(word => word.length > 0);
                    console.log("Broken:", brokenTags);

                    // Save original PDF path and image paths to database
                    const newpost = new Profiles({
                        firstname: user_data.firstname,
                        lastname: user_data.lastname,
                        username: up_username,
                        postID: `${up_username}-${uuidv4()}`,
                        file: filePath, // Store the PDF file path
                        imagePaths: imagePaths, // Store the array of image paths
                        post_type: post_type,
                        post_desc: post_desc,
                        post_likes: 0,
                        hashtags: cleanedHashtags,
                        broken_tags: brokenTags,
                        approved: false,
                        interface: interface
                    });

                    await newpost.save();
                    logMessage(`[=] ${interface} ${userIP} : Posted a file ${up_username}-${filename}`);
                    return res.status(200).json({ message: "Uploaded Successfully" });
                })
                .catch(error => {
                    console.error('Error converting PDF to images:', error);
                    return res.status(500).json({ message: "Error converting PDF to images" });
                });

        } else if (post_type === "mentor_file_upload") {
            // Handle other file upload types
            addMentees(up_username, req.file.filename, post_desc, selection, userIP, interface);
        }

    } catch (error) {
        console.error(`[*] Internal server error: ${error}`);
        res.status(500).json({ message: "Internal server error" });
    }
});


server.post("/myprofile", async (req, res) => {
    let userIP = req.headers['x-forwarded-for'] || req.socket.remoteAddress;


    if (Array.isArray(userIP)) {
        userIP = userIP[0];
    } else if (userIP.includes(',')) {
        userIP = userIP.split(',')[0].trim();
    }

    const { Token, interface } = req.body;
    const tokencheck = await CSRFToken.findOne({ token: Token });

    if (tokencheck) {
        try {
            const user_profile_data = await Profiles.find({ username: tokencheck.username });
            const user_credly_data = await Credly.find({ username: tokencheck.username });

            // Include the file paths for images
            const profilePosts = user_profile_data.map(post => {
                if (post.file) {
                    const images = fs.readdirSync(path.dirname(post.file))
                        .filter(file => file.startsWith(path.basename(post.file, path.extname(post.file))) && file.endsWith('.jpg'))
                        .map(file => `/uploads/${post.username}/${file}`);
                    return {
                        ...post._doc,
                        images,
                        post_desc: post.post_desc
                    };
                }
                return post;
            });

            logMessage(`[=] ${interface} ${userIP} : ${tokencheck.username} pulled their own profile`);
            res.status(200).json({ data: profilePosts, credly: user_credly_data });
        } catch (error) {
            logMessage(`[*] ${interface} ${userIP} : Internal server error ${error}`);
            res.status(500).json({ message: "Internal server error" });
        }
    } else {
        res.status(400).json({ message: "Invalid Token" });
    }
});


server.post('/deletePost', async (req, res) => {
    let userIP = req.headers['x-forwarded-for'] || req.socket.remoteAddress;


    if (Array.isArray(userIP)) {
        userIP = userIP[0];
    } else if (userIP.includes(',')) {
        userIP = userIP.split(',')[0].trim();
    }
    const { Token, postID, interface } = req.body;
  
    const token_check = await CSRFToken.findOne({token : Token});
    const username = token_check.username;

    const profilesdata = await Profiles.findOne({ username : username , postID : postID});

    if(profilesdata)
    {
        try {
            await Profiles.deleteOne({ postID: postID });
            logMessage(`[=] ${interface} ${userIP} : Deleted post ${postID}`);

            // Step 2: Delete the associated files
            const uploadsDir = path.join(__dirname, `uploads/${username}/`); // Adjust the path as needed

            // Function to delete a file
            const deleteFile = (filePath) => {
              fs.unlink(filePath, (err) => {
                if (err) {
                  logMessage(`[*] ${interface} ${userIP} : Error deleting file ${filePath} - ${err}`);
                } else {
                  logMessage(`[=] ${interface} ${userIP} : Deleted file ${filePath}`);
                }
              });
            };
        
            // Delete the PDF file and images
            const files = fs.readdirSync(uploadsDir);
            files.forEach((file) => {
              if (file.includes(postID)) {
                const filePath = path.join(uploadsDir, file);
                deleteFile(filePath);
              }
            });
          res.status(200);
        } catch (error) {
          logMessage('[*] Error deleting post:', error);
          res.status(500).json({ message: 'Error deleting post' });
        }
    }
    else{
        logMessage(`[-] ${interface} ${userIP} : Treid to delete no existing post ${postID}`);
    }
  });


server.post("/mybatches" ,async(req,res) =>{
    let userIP = req.headers['x-forwarded-for'] || req.socket.remoteAddress;


    if (Array.isArray(userIP)) {
        userIP = userIP[0];
    } else if (userIP.includes(',')) {
        userIP = userIP.split(',')[0].trim();
    }
    const {Token , username , interface} = req.body;
    if(Token)
    {
        try
        {
            tocken_check = await CSRFToken.findOne({ token : Token});
            if (tocken_check.username == username )
            {
                const batches = await Mentor.find({mentor : username})
                if (batches.length > 0 )
                {
                    res.status(200).json({ data: batches });
                    logMessage(`${interface} ${userIP} : Mentor ${username} fetch their badges info`);
                }
                else
                {
                    res.status(201);
                }
            }
        }
        catch(e)
        {
            logMessage(`${interface} ${userIP} : Internal server error : ${e}`);
            res.status(500);
        }
    }
    

});

server.post('/delete-batch', async (req, res) => {
    let userIP = req.headers['x-forwarded-for'] || req.socket.remoteAddress;


    if (Array.isArray(userIP)) {
        userIP = userIP[0];
    } else if (userIP.includes(',')) {
        userIP = userIP.split(',')[0].trim();
    }

    const { username, batchName,Token } = req.body; // Extract username and batchName from request body
    if (Token) 
    {    

        try {
            tocken_check = await CSRFToken.findOne({ token : Token})
            if (tocken_check.username == username )
            {// Find and delete the batch for the given username and batch name
                const result = await Mentor.findOneAndDelete({
                    mentor: username,
                    batch: batchName
                });

                if (result) {
                    logMessage(`[=] ${userIP} : ${username} deleted thier batch`);
                    res.status(200).json({ message: 'Batch deleted successfully' });
                } else {
                    res.status(404).json({ message: 'Batch not found' });
                }
            }
        } catch (error) {
            logMessage(`[*] ${userIP} : Internal server error while delteing batch :${error}`);
            res.status(500).json({ message: 'Internal server error' });
        }
    }
});


server.post("/extract-hashtags", extract_hashtag_folder.single('file'), async (req, res) => {
    let userIP = req.headers['x-forwarded-for'] || req.socket.remoteAddress;

    if (Array.isArray(userIP)) {
        userIP = userIP[0];
    } else if (userIP.includes(',')) {
        userIP = userIP.split(',')[0].trim();
    }

    const { Token, interface, filename, up_username } = req.body;
    console.log("Token:", Token, "interface:", interface, "Filename:", filename, "username:", up_username);
    const filePath = req.file.path;

    try {
        const flaskResponse = await axios.post('http://localhost:5000/autohash', {
            filePath: filePath,
            mode: "pdf"
        });
        const hashtags = flaskResponse.data.hashtags;

        if (!hashtags || hashtags.length === 0) {
            const opts = {
                format: 'jpeg',
                out_dir: path.join(__dirname, 'hashtag_extractions'),
                out_prefix: `${path.basename(filePath, path.extname(filePath))}`,
                page: 1 // Only convert the first page
            };

            if (!fs.existsSync(opts.out_dir)) {
                fs.mkdirSync(opts.out_dir, { recursive: true });
            }

            await pdf.convert(filePath, opts);
            console.log("First page of PDF converted to image successfully");

            const imageFiles = fs.readdirSync(opts.out_dir)
                .filter(file => file.startsWith(opts.out_prefix) && file.endsWith('.jpeg'))
                .sort();

            if (imageFiles.length > 0) {
                const oldPath = path.join(opts.out_dir, imageFiles[0]);
                const newPath = path.join(opts.out_dir, `${opts.out_prefix}-1.jpeg`);
                fs.renameSync(oldPath, newPath);
                console.log(`Renamed ${imageFiles[0]} to ${opts.out_prefix}-1.jpeg \n NEWPATHS ${newPath}`);

                // Call the Flask OCR function with the image path for further hashtag extraction
                const ocrResponse = await axios.post('http://localhost:5000/autohash', {
                    filePath: newPath,
                    mode: "image"
                });

                const ocrHashtags = ocrResponse.data.hashtags || [];
                return res.status(200).json(ocrHashtags);
            } else {
                console.error('No image file was created.');
                return res.status(500).json({ message: 'Failed to create image for OCR' });
            }
        }
        return res.status(200).json(hashtags);

    } catch (error) {
        console.error('Error communicating with Flask server:', error);
        return res.status(500).json({ message: 'Failed to extract hashtags' });
    }
});


server.post("/postpermission" ,async (req, res) => {
    const userIP = req.headers['x-forwarded-for'] || req.socket.remoteAddress;

    if (Array.isArray(userIP)) {
        userIP = userIP[0];
    } else if (userIP.includes(',')) {
        userIP = userIP.split(',')[0].trim();
    }

    console.log("POST PERMISSION");

    const { Token, up_username ,interface} = req.body;

    const check_token = await CSRFToken.findOne({ token: Token });
    console.log("Token:", Token, "username:", check_token?.username);

    if (check_token.username) {
        const mybatches_data = await Mentor.find({ mentor: check_token.username });
        console.log("Token true\n", mybatches_data);

        let results = {};

        for (const batchData of mybatches_data) {
            const batchName = batchData.batch;
            const studentsNames = batchData.students;
            const studentsUsernames = batchData.username;

            results[batchName] = {};

            for (let i = 0; i < studentsNames.length; i++) {
                const studentName = studentsNames[i];
                const studentUsername = studentsUsernames[i];

                // Fetch unapproved posts for the student
                const unapprovedPosts = await Profiles.find({
                    username: studentUsername,
                    approved: false
                });

                // Map unapproved posts to include all required fields
                results[batchName][studentName] = unapprovedPosts.map(post => ({
                    postId: post.postID,
                    imagePaths: post.imagePaths, // Ensure this field is included
                    post_desc: post.post_desc,
                    post_type: post.post_type,
                    post_likes: post.post_likes,
                    file: post.file,
                    interface: post.interface,
                    approved: post.approved
                }));
            }
        }
        logMessage(`[=] ${interface} ${userIP} : ${check_token.username} fetched post permissions`);

        res.status(200).json(results);

    } else {
        logMessage(`[-] ${interface} ${userIP} : ${check_token.username} couldn't fetched post permissions`);
        res.status(404).send("Token not valid");
    }
});

server.post("/status-post",async(req,res)=> {
    const userIP = req.headers['x-forwarded-for'] || req.socket.remoteAddress;

    if (Array.isArray(userIP)) {
        userIP = userIP[0];
    } else if (userIP.includes(',')) {
        userIP = userIP.split(',')[0].trim();
    }

    const {Token , postId , up_username , status , interface } = req.body;
    if (Token)
    {    
        const check_token = await CSRFToken.findOne({ token : Token});
        if (check_token.username == up_username)
        {
            if(status == "approved")
            {
                try {

                    const result = await Profiles.findOneAndUpdate(
                      { postID: postId }, 
                      { $set: { approved: true } }, 
                      { new: true } 
                    );
                
                    if (!result) {
                      return res.status(404).json({ message: 'Post not found' });
                    }
                    logMessage(`[=] ${interface} ${userIP} : ${up_username} approved post ${postId}`)
                    return res.status(200).json({ message: 'Post approved successfully'});
                  } catch (error) {
                    logMessage(`[*] Internal Server error : failed to approved post :${error}`)
                    return res.status(500).json({ message: 'Internal Server error' });
                  }
            }
            else if (status == 'rejected')
            {
                try {
                    console.log("REJECTED : ",postId);
                    await Profiles.deleteOne({postID : postId});
                    logMessage(`[=] ${interface} ${userIP} : ${up_username} rejected post ${postId}`);
                    return res.status(200).json({ message: 'Post rejected successfully'});
                } catch (error) {
                    logMessage(`[*] Internal Server error : rejected post ${postId} ,error ${error}`);
                    return res.status(200).json({ message: 'Internal Server error'});
                }
            }
        }
        else{
            logMessage(`[-] ${interface} ${userIP} : Invalid request : ${up_username} ${postId}`);
            return res.status(404).json({ message: 'invalid request' });
        }
}
});



server.listen(8000, () => {
    console.log(`http://localhost:8000`);
  })
