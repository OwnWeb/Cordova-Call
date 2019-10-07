cordova.define("cordova-call.CordovaCall", function(require, exports, module) {
  var exec = require('cordova/exec');
  
  exports.registerVoipPush = function(tokenCallback,notificationCallback) {
    if (!tokenCallback) { tokenCallback = function() {}; }
    if (!notificationCallback) { notificationCallback = function() {}; }
  
    var errorCallback = function() {};
    var successCallback = function(obj) {
       if (obj.hasOwnProperty('token')) {
          tokenCallback(obj);
       } else if (obj.hasOwnProperty('payload')) {
          notificationCallback(obj);
       }
    };
  
    exec(successCallback, errorCallback, 'CordovaCall', 'voipRegistration' );
  };
  
  exports.setAppName = function(appName, success, error) {
      exec(success, error, "CordovaCall", "setAppName", [appName]);
  };
  
  exports.getApplicationState = function(success, error) {
    exec(success, error, "CordovaCall", "getApplicationState");
  };
  
  exports.setIcon = function(iconName, success, error) {
      exec(success, error, "CordovaCall", "setIcon", [iconName]);
  };
  
  exports.setRingtone = function(ringtoneName, success, error) {
      exec(success, error, "CordovaCall", "setRingtone", [ringtoneName]);
  };
  
  exports.setIncludeInRecents = function(value, success, error) {
      if(typeof value == "boolean") {
        exec(success, error, "CordovaCall", "setIncludeInRecents", [value]);
      } else {
        error("Value Must Be True Or False");
      }
  };
  
  exports.setDTMFState = function(value, success, error) {
      if(typeof value == "boolean") {
        exec(success, error, "CordovaCall", "setDTMFState", [value]);
      } else {
        error("Value Must Be True Or False");
      }
  };
  
  exports.setVideo = function(value, success, error) {
      if(typeof value == "boolean") {
        exec(success, error, "CordovaCall", "setVideo", [value]);
      } else {
        error("Value Must Be True Or False");
      }
  };
  
  exports.receiveCall = function(name, number, callId, supportsHold, success, error) {
      exec(success, error, "CordovaCall", "receiveCall", [name, number, callId, supportsHold]);
  };
  
  exports.sendCall = function(to, id, supportsHold, success, error) {
    if(typeof id == "function") {
      error = success;
      success = id;
      id = undefined;
      supportsHold = undefined;
    } else if(id) {
      id = id.toString();
    }
    exec(success, error, "CordovaCall", "sendCall", [to, id, supportsHold]);
  };
  
  exports.connectCall = function(uuid, success, error) {
      exec(success, error, "CordovaCall", "connectCall", [uuid]);
  };
  
  exports.endCall = function(uuid, acceptedElsewhere,  success, error) {
    if(typeof acceptedElsewhere == "function") {
      error = success;
      success = acceptedElsewhere;
      acceptedElsewhere = undefined;
    }
    exec(success, error, "CordovaCall", "endCall", [uuid, acceptedElsewhere]);
  };
  
  exports.setMuteCall = function(uuid, mute, success, error) {
    exec(success, error, "CordovaCall", "setMuteCall", [uuid, mute])
  };
  
  exports.mute = function(success, error) {
      exec(success, error, "CordovaCall", "mute", []);
  };
  
  exports.unmute = function(success, error) {
      exec(success, error, "CordovaCall", "unmute", []);
  };
  
  exports.speakerOn = function(success, error) {
      exec(success, error, "CordovaCall", "speakerOn", []);
  };
  
  exports.speakerOff = function(success, error) {
      exec(success, error, "CordovaCall", "speakerOff", []);
  };
  
  exports.callNumber = function(to, success, error) {
      exec(success, error, "CordovaCall", "callNumber", [to]);
  };
  
  exports.on = function(e, f) {
      var success = function(message) {
        f(message);
      };
      var error = function() {
      };
      exec(success, error, "CordovaCall", "registerEvent", [e]);
  };
  
  exports.keepAlive = function(active, success, error) {
    exec(success, error , "CordovaCall", "keepAlive", [active]);
  };
    
  exports.limitedBackgroundExecution = function(enable, success, error) {
    exec(success, error , "CordovaCall", "enableLimitedBackgroundExecution", [enable]);
  };
  });
  