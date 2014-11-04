

var ScanndyLoader = function (require, exports, module) {
    
    var exec = require("cordova/exec");
    
    /**
     * Constructor.
     *
     * @returns {SmartScanndy}
     */
    function SmartScanndy() {
        
    };
    
    /**
     * Read rfid code from scanner.
     *
     * @param {Function} successCallback This function will recieve a result object: {
     *        result : 'xxxxxxxxxxxxxxx',    // the raw 64bit code.
     *        resultraw : 'xxxxxxxxxx', // the raw result string
     *        result40 : 'xxxxxxxxxx', // the decoded 40bit code
     *        result13 : 'xxxxx', // the decoded 13bit code
     *    }
     * @param {Function} errorCallback
     */
    SmartScanndy.prototype.rfidscan = function (successCallback, errorCallback) {
        if (errorCallback == null) {
            errorCallback = function () {
            };
        }
        
        if (typeof errorCallback != "function") {
            console.log("SmartScanndy.rfidscan failure: failure parameter not a function");
            return;
        }
        
        if (typeof successCallback != "function") {
            console.log("SmartScanndy.rfidscan failure: success callback parameter must be a function");
            return;
        }
        
        var scanndyCommand = 'rfidscan:tid';
        
        exec(successCallback, errorCallback, 'CDVSmartScanndy', 'rfidscan', [scanndyCommand]);
    };
    
    
    var smartScanndy = new SmartScanndy();
    module.exports = smartScanndy;
    
}

ScanndyLoader(require, exports, module);

cordova.define("cordova/plugin/SmartScanndy", ScanndyLoader);
