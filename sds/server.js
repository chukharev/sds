// SDS Framework for Applied Linguisitcs
// License: CC0 1.0, https://creativecommons.org/publicdomain/zero/1.0/
// To the extent possible under law, Evgeny Chukharev-Hudilainen has waived all copyright and related or neighboring rights to this software.
// This work is published from the United States of America.

'use strict';

var express = require('express'), bodyParser = require('body-parser');
var app = express();
var expressWs = require('express-ws')(app);
var fs = require('fs');
var _ = require('underscore');
var aws = require('aws-sdk')
var exec0 = require('child_process').exec;
var port = 8309;

// connect to Amazon
// TODO: add your AWS key to the file aws-key.json
aws.config.loadFromPath(__dirname + '/aws-key.json')
var TTS = new aws.Polly();

// connect to Google
// TODO: add your Google Cloud key to the file aws-key.json
var speech = require('@google-cloud/speech');
var ASR = new speech.SpeechClient( {keyFilename: __dirname + '/google-key.json'} );

var exchanges = {};

var Exchange = function(p) {
  if (!p) p = {};
  this.id = Date.now() + Math.random();
  if (p.label && /^[\w-]+$/.test(p.label)) {
    this.id = p.label+'-'+this.id;
  }
  this.status = 'init';
  exchanges[this.id] = this;
  fs.mkdir("recordings/"+this.id);
  this.turnNo = 1;
  this.freq = 0;
}

Exchange.prototype = {
  debug: function(d) {
    if (this.id) {
      console.log(this.id+': '+d);
      fs.appendFile(this.id+'/debug_log.txt', d+"\n", ()=>{})
    } else {
      console.log(d);
    }
  },

  socketData: function(data) {
    var s = data.toString('utf-8');
    this.debug('Received from socket: ' + s);

    let match1 = /\*(\d+)([sw])\s*$/.exec(s);
    if (match1) {
      let delay = 1/1000, wordCount = 1;
      s = s.replace(/\*\w+\s*$/, '');
      if (match1[2] === 's') delay = parseInt(match1[1]);
      else wordCount = parseInt(match1[1]);
      let that = this;
      setTimeout(() => that.scheduleInterruption(delay * 1000, wordCount), 100);
    }
    this.say(s);
  },
  socketClose: function() { this.done() },
  userAudio: function(raw) {
    let that = this;
    if (this.listeningToUser) {
      if (!this.asrStream) this.asrStreamInit();
      this.asrStream.write(raw);
      this.writeStream.write(raw);
      if (this.wsTimeout) clearTimeout(this.wsTimeout);
      this.wsTimeout = setTimeout(() => { delete that.wsTimeout; that.socketClose() }, 5000);
    } else {
    }
  },
  asrStreamEnd: function() {
    this.listeningToUser = false;
    if (this.wsTimeout) clearTimeout(this.wsTimeout);
    delete this.wsTimeout;
    if (this.asrStream) {
      this.asrStream.end();
      delete this.asrStream;
    }
    if (this.writeStream) {
      let t = this.writeStream;
      this.writeStream.end();
      delete this.writeStream;
      let cmd = 'cd recordings/'+this.id+' && ffmpeg -f s16le -ar '+this.freq+' -ac 1 -i '+this.turnNo+'.raw -f mp3 '+this.turnNo+'u.mp3';
      //this.debug(cmd);
      exec0(cmd);
    }
  },
  asrStreamInit: function() {
    let that = this;
    if (this.status !== 'live' || !this.freq) return;

    this.silenceTimeout = setTimeout(() => that.userSaid(''), 10000);

    let request = {
      config: {
        encoding: 'LINEAR16',
        sampleRateHertz: this.freq, //44100/4
        languageCode: 'en-US',
        maxAlternatives: 1,
        speechContexts: [{ "phrases": ["tutor"] }]
      },
      interimResults: true
    };
    this.writeStream = fs.createWriteStream('recordings/'+this.id+'/'+this.turnNo+'.raw');
    this.asrStream = ASR
    .streamingRecognize(request)
    .on('error', () => that.userSaid(''))
    .on('data', data => {
      if (!data.results || !data.results.length) return;
      if (data.results[0].isFinal) {
        that.userSaid(data.results[0].alternatives[0].transcript);
      } else {
        that.userSpeaking(data.results[0].alternatives[0].transcript);
      }
    });
  },
  userSpeaking: function(what) {
    this.debug('userSpeaking: '+what);
    this.curUserTurn = what;
    if (this.silenceTimeout) clearTimeout(this.silenceTimeout);
    delete this.silenceTimeout;
    
    if (this.interruption) {
      let words = this.curUserTurn.split(' ');
      if (this.interruption.wordCount <= words.length && !this.interruptionTimeout) {
        this.debug('SCHEDULED INTERRUPTION IN ', this.interruption.when);
        let that = this;
        this.interruptionTimeout = setTimeout(function() { that.doInterruption() }, this.interruption.when);
        delete this.interruption;
      }
    }
  },
  scheduleInterruption: function(when, wordCount) {
    this.interruption = { when: when, wordCount: wordCount };
    this.debug('Interruption scheduled: when='+when+', wordCout='+wordCount);
  },
  doInterruption: function() {
    if (this.interruptionTimeout) {
      delete this.interruptionTimeout;
      this.asrStreamEnd();
      this.debug('interrupt: '+ this.curUserTurn);
      this.userLastSaid = this.curUserTurn;
      if (this.socket) this.socket.write(this.curUserTurn+" *\n");
      delete this.interruption;
    }
  },
  userSaid: function(what) {
    if (!this.asrStream) return;
    this.debug('userSaid: ' + what);
    this.userLastSaid = what;
    this.asrStreamEnd();
    if (this.socket) {
      console.log('sent to socket');
      this.socket.write(what+"\n");
    }
    delete this.interruptionWhen;
  },
  say: function(what) {
    let t = this;
    this.myTurn = what;
    fs.appendFile('recordings/'+this.id+'/transcript.txt', this.turnNo+'\tu\t'+(this.userLastSaid||'')+"\n"+this.turnNo+"\tc\t"+what+"\n", ()=>{});
    this.asrStreamEnd();

    this.turnNo++;
    delete this.userLastSaid;
    delete this.interruption;
    if (this.interruptionTimeout) {
      clearTimeout(this.interruptionTimeout);
      delete this.interruptionTimeout;
    }
    if (this.silenceTimeout) {
      clearTimeout(this.silenceTimeout);
      delete this.silenceTimeout;
    }
    this.curUserTurn = '';
    if (this.ws) {
      if (this.ws.readyState === this.ws.OPEN) {
        this.ws.send('1');
      } else {
        this.socketClose();
      }
    }
  },
  done: function() {
    //delete exchanges[this.id];
    this.debug(this.id + ' done');
    if (this.status !== 'done') {
      this.status = 'done';
      if (this.socket) this.socket.write("*BYE\n");
      if (this.ws) this.ws.close();
    }
  },
  yieldMyTurn: function(req, res) {
    let that=this;
    this.debug('Synthesizing: '+this.myTurn);
    //if (!this.myTurn) return res.status(404).send("No turn available");
    console.log(this.config);
    let voice = this.config.voice || 'Joanna';
    let toSay = this.myTurn;
    let params = {
      OutputFormat: 'mp3', 
      Text: toSay, 
      TextType: "text", 
      VoiceId: voice,
      Engine: 'neural'
    };
    TTS.synthesizeSpeech(params, function(err, data) {
      if (err) return res.status(403).send('Failed to synthesize speech');
      res.writeHead(200, {"Content-Type": data.ContentType});
      res.end(data.AudioStream);
      let w = fs.createWriteStream('recordings/'+that.id+'/'+(that.turnNo-1)+'c.mp3');
      w.end(data.AudioStream);
    });
    this.myTurn = '';
    this.listeningToUser = true;
  }
}

app.use(bodyParser.json());
app.get('/', function(req,res) { res.sendFile(__dirname + '/index.html') });
app.get('/client.js', function(req,res) { res.sendFile(__dirname + '/client.js') });
app.get('/transcript', function(req,res) { res.sendFile(__dirname + '/transcript.html') });

var net = require('net');


var DMMServer = net.createServer(onDMMConnected);  
DMMServer.listen(9999, '127.0.0.1', function() {  
  console.log('DMM server listening on %j', DMMServer.address());
});
 
function onDMMConnected(sock) {  
  var remoteAddress = sock.remoteAddress + ':' + sock.remotePort;
  console.log('new DMM connected: %s', remoteAddress);

  let once=0;
  sock.on('data', (data) => {
    if (once++) return;
    let s = data.toString('utf-8');
    let config = JSON.parse(s);
    if (config.id && exchanges[config.id] && !exchanges[config.id].socket) {
      let e = exchanges[config.id];
      console.log(config);
      e.config = config;
      e.socket = sock;
      sock.on('data', (data) => e.socketData(data));
      sock.on('close', () => e.socketClose());
      sock.on('error', () => e.socketClose());
      e.status = 'live';
      e.userSaid(''); //????
      return;
    }
    sock.end('*BYE\n');
  });
}

app.ws('/:id/mic', function(ws, req) {
  let id = req.params.id;
  let e = exchanges[id];
  if (e) {
    e.ws = ws;
    ws.on('message', (msg) => e.userAudio(msg));
    ws.on('error', () => e.socketClose());
    ws.on('close', () => e.socketClose());
    if (e.myTurn) e.ws.send('1');
  }
});

app.all('/:id/sample-rate/:rate', function(req, res) {
  let id = req.params.id;
  let e = exchanges[id];
  if (e) e.freq = parseInt(req.params.rate);
  res.send('ok');
});

app.get('/:id/audio', function(req, res) {
  let id = req.params.id;
  let e = exchanges[id];
  if (e) e.yieldMyTurn(req, res);
  else res.send('err');
});
 
app.post('/init', function(req, res) {
  let e = new Exchange(req.body);
  res.json({ id: e.id });
  let dmm = req.body.dmm || 'hospitality';
  if (!/^\w+$/.test(dmm)) dmm = 'hospitality';
  let cmd = 'cd dmm && ./'+dmm+'.pl '+e.id;
  console.log(cmd);
  exec0(cmd);
});

app.all('/:id/status', function(req, res) {
  let id = req.params.id;
  let e = exchanges[id];
  let status = { id: id, status: 'gone' };
  if (e) _.extend(status, { status: e.status, config: e.config });
  res.json(status);
});

app.get('/mp3/:id/:no', function(req, res) {
  let id = req.params.id;
  let no = req.params.no;
  res.sendFile(__dirname + "/recordings/" + id + "/" + no + ".mp3");
});

app.all('/:id/transcript', function(req, res) {
  let id = req.params.id;
  fs.readFile("recordings/"+id+"/transcript.txt", "utf8", function(err, data) {
    let t = [];
    if (data) {
      let sp = data.split("\n");
      for (let i=0; i<sp.length; i++) {
        let sp1 = sp[i].split("\t");
        if (sp1.length === 3) t.push(sp1);
      }
      res.json(t);
    } else res.status(403).send('Failed to get transcript');
  });
});

app.listen(port);