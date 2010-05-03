jQuery.ajax.post = function(url, data, succFunc) {
    var async, errFunc;
    if (arguments.length < 5) {
        async = false;
        if (arguments.length < 4) {
            errFunc = function() {};
        } else {
            errFunc = arguments[3];
        }
    } else {
        async = arguments[4];
    }
    return $.ajax({
        'type': 'POST',
        'url': url,
        'data': data,
        'dataType': 'json',
        'timeout': ajaxResponseMaxTime,
        'async': async,
        success: function(dataResponse, textStatus, XMLHttpRequest) {
            if (dataResponse['result'] != 'ok') {
                $("#message_to_admin").html(
                    String.format(
                        "Ajax response result is <b>{0}</b> instead of <b>ok</b><pre><code>\n{1}</code></pre>",
                        dataResponse['result'],
                        XMLHttpRequest.responseText
                    )
                 );   
                errFunc(XMLHttpRequest, textStatus, undefined);
            } else {
                $("#message_to_admin").html('');
                succFunc(dataResponse, textStatus, XMLHttpRequest);
            }
        },
        error: function(XMLHttpRequest, textStatus, errorThrown) {
            $("#message_to_admin").html(
                "Ajax request has been completed with following error:\n" +
                    (errorThrown ? errorThrown : XMLHttpRequest.responseText)
            );
            errFunc(XMLHttpRequest, textStatus, errorThrown);
        },
    });
}


String.format = function() {
    var s = arguments[0];
    for (var i = 0; i < arguments.length - 1; i++) {
        var reg = new RegExp("\\{" + i + "\\}", "gm");
        s = s.replace(reg, arguments[i + 1]);
    }
    return s;
}


Array.prototype.insertAfter = function(num, elem) {
    this.push(undefined);
    var i = this.length - 1;
    num++;
    while (i > num) {
        this[i] = this[i-1];
        i--;
    }
    this[i] = elem;
}


function timestampToDate(timestamp) {
    var m = timestamp.match(/^(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d).(\d{4})$/);
    for (var i = 1; i < m.length; i++) {
        m[i] -= 0; //toInt
    }
    return new Date(m[1], m[2]-1, m[3], m[4], m[5], m[6], m[7]/10);
}


function dateToTimestamp(date) {
    var year = zeroFill(date.getFullYear(), 4);
    var mon = zeroFill(date.getMonth() + 1, 2);
    var mday = zeroFill(date.getDate(), 2);
    var hour = zeroFill(date.getHours(), 2);
    var min = zeroFill(date.getMinutes(), 2);
    var sec = zeroFill(date.getSeconds(), 2);
    var msec = zeroFill(date.getMilliseconds() * 10, 4, true);
    return String.format('{0}-{1}-{2} {3}:{4}:{5}.{6}', year, mon, mday, hour, min, sec, msec);
}


function zeroFill (value, capacity, after) {
    value += ''; //toString
    while (value.length < capacity) {
        if (after) {
            value += '0';
        } else {
            value = '0' + value;
        }
    }
    return value;
}


Date.prototype.msecAdd = function(msec) {
    this.setMilliseconds(this.getMilliseconds() + msec);
    return this;
}


function defined(obj) {
    return obj != undefined;
}


const Timer = $.inherit(
    {
        __constructor : function(delegate, upTime) {
            this.delegate = delegate;
            this.upTime = upTime;
        },
        
        start : function() {
            this.updating = true;
            this.timer();
        },
        
        timer : function() {
            if (this.updating) {
                this.delegate();
                window.setTimeout(utils.delegate(this, this.timer), this.upTime);
            }
        },
        
        stop : function() {
            this.updating = false;
        },
        
        restart : function() {
            window.setTimeout(utils.delegate(this, this.timer), this.upTime);
        },
        
        changeUpTime : function(newUpTime) {
            this.upTime = newUpTime;
        },
    }
);


const Utils = $.inherit(
    {
        delegate : function(that, thatMethod) {
            return function() {return thatMethod.apply(that, arguments);};
        },
        
        timer : function(delegate, upTime) {
            var timer = new Timer(delegate, upTime);
            timer.start();
            return timer;
        },  
        
        getMainURL : function() {
            return window.location.href.match(/^(.+pl)\?/)[1];
        },
    }
);

const utils = new Utils();
