// SDS Framework for Applied Linguisitcs
// License: CC0 1.0, https://creativecommons.org/publicdomain/zero/1.0/
// To the extent possible under law, Evgeny Chukharev-Hudilainen has waived all copyright and related or neighboring rights to this software.
// This work is published from the United States of America.

var domain = 'yourdomain.com'; // TODO: change this

window.SDS = function(parameters, callback) {
  var id;
  var ws, listening, currentStatus;

  function status(s) {
    if (currentStatus !== s) {
      currentStatus = s;
      if (callback) callback(s);
    }
  }

  $.ajax({
    url: '/sds/init',
    type: 'POST',
    contentType: 'application/json',
    data: JSON.stringify(parameters),
    dataType: 'json',
    success: function(data) {
      if (data.id) {
        window.SDS.id = id = data.id;
        setTimeout(checkStatus, 1000);
      } else {
        status('failed');
      }
    }, function() {
      status('failed');
    }
  });

  var config = {};

  function checkStatus() {
    $.getJSON("/sds/"+id+"/status", function(data) {
      status(data.status);
      if (data.status === 'live') {
        config = data.config;
        initExchange();
      }
      else setTimeout(checkStatus, 1000);
    }, function() {
      status('failed');
    });
  }

  var audioElement, sourceElement;

  function playTurn() {
    listening = false;
    sourceElement.src='/sds/'+id+'/audio?r='+Math.random();
    audioElement.load();
    status('speaking');
  }

  function done() {
    status('done');
  }

  function initExchange() {
    listening = true;
    audioElement = document.createElement('audio');
    audioElement.setAttribute('autoplay', 'autoplay');
    sourceElement = document.createElement('source');
    sourceElement.setAttribute('type', 'audio/mp3');
    audioElement.appendChild(sourceElement);
    audioElement.onended = function() { listening = true; status('listening') }
    audioElement.onerror = function() { listening = true; status('listening') }
    ws = new WebSocket('wss://'+domain+'/sds/'+id+'/mic');
    ws.binaryType = 'blob';
    ws.onmessage = function() {
      console.log('message received');
      playTurn();
    }
    ws.onclose = function() {
      done();
    }
    navigator.mediaDevices.getUserMedia({ audio: true, video: false }).then(mediaGotten);
  }

  
  function downsample(buffer, div) {
    var l = buffer.length;
    //var div = 2;
    var buf = new Int16Array(l/div);
    var sum = 0;
    var count = 0;
    var bufi = 0;
    for (var i=0; i<l; i++) {
      sum += buffer[i];
      count++;
      if (count === div) {
        var avg = sum / count;
        buf[bufi] = Math.min(1, avg)*0x7FFF;
        bufi++;
        sum = count = 0;
      }
    }
    return buf;
  }
  function getMaxOfArray(numArray) {
    return Math.max.apply(null, numArray);
  }
  function getMinOfArray(numArray) {
    return Math.min.apply(null, numArray);
  }
  function amplitude(buffer) {
    var minSample = getMinOfArray(buffer);
    var maxSample = getMaxOfArray(buffer);
    return (maxSample-minSample);
  }

  var mediaGotten = function(stream) {
    var context = new AudioContext();
    $.post("/sds/"+id+"/sample-rate/"+parseInt(context.sampleRate/2));

    var source = context.createMediaStreamSource(stream);
    var processor = context.createScriptProcessor(1024, 1, 1);

    source.connect(processor);
    processor.connect(context.destination);

    processor.onaudioprocess = function(e) {
      var inputData = e.inputBuffer.getChannelData(0);
      var converted = downsample(inputData, 2);
      console.log(converted);
      
      if (ws && listening) ws.send(converted);
    };
  };
}
