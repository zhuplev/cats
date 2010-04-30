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


String.min = function(a, b) {
    return a < b ? a : b;
}


String.max = function(a, b) {
    return a > b ? a : b;
}


Array.prototype.append = function(a, b) {
    var result = a;
    for (var i in b) {
        result.push(b[i]);
    }
    return result;
}


Array.prototype.insertAfter = function(list, num, elem) {
    var result = list;
    result.push(undefined);
    var i = result.length - 1;
    num++;
    while (i > num) {
        result[i] = result[i-1];
        i--;
    }
    result[i] = elem;
    return result;
}


Object.size = function(obj) {
    var size = 0;
    for (var key in obj) {
        if (obj.hasOwnProperty(key)) size++;
    }
    return size;
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
