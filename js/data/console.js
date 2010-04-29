const DataConsoleAtom = {
    submission : 1 << 0,
    message : 1 << 1,
    contest : 1 << 2,
};
//Как бэ не настаиваю на именно таком задании параметров.
//Поэтому вся проверка "маски" вынесена в отдельные функции, при желании можно переписать.


const DataConsoleDateInf = '9';


const DataConsole = $.inherit(
    DataAbstract,
    {
        __constructor : function() {
            this.__base();
            this.setParam('f', 'console');
            this.ids = {
                'teams' : {},
                'problems' : {},
            };
            this.lists = {
                'submissions' : [],
                'messages' : [],
                'contests' : [],
            };
            this.current = [];
            this.time = '';
        },
        
        start : function() {
            //var timer = utils.timer(utils.delegate(this, this.sendRequest), 5000);
            
        },
        
        sendRequest : function() {
            jQuery.ajax.post(utils.getMainURL(), this.getRequest(), utils.delegate(this, this.response));
            this.json = {};
        },
        
        response : function(dataResponse, textStatus, XMLHttpRequest) {
            this.updateIds(dataResponse, 'teams');
            this.updateIds(dataResponse, 'problems');
            this.time = dataResponse.server_timestamp;
            this.current = [];
            
            for (var key in this.lists) {
                this.updateData(this.lists[key], dataResponse.console[key]);
            }
            $('#message_to_admin').html(XMLHttpRequest.responseText);
            //this.interfaceUpdateEvent();
        },
        
        updateIds : function(dataResponse, idType) {
            if (defined(dataResponse.console)) {
                for (var key in dataResponse.console[idType]) {
                    this.ids[idType][key] = dataResponse.console[idType][key];
                }
            }
        },
        
        updateData : function(existingList, newData) {
            existingList = [];
            for (var i in newData) {
                //existingList.push(newData[i]);
                this.current.push(newData[i]);
            }
        },
    }
);
 
 
const DataConsoleFragment = $.inherit(
    {
        __constructor : function(since, to, s, m, c) {
            this.since = since;
            this.to = to;
            this.s = s; this.m = m; this.c = c; //submissions, messages, contests
            this.reset();
        },
        
        reset : function() {
            this.sc = 0; this.mc = 0; this.cc = 0; //counters
        },
        
        changeMask : function(mask) { //ASK: setMask?
            this.mask = mask;
            this.sl = (this.inMask(DataConsoleAtom.submission)) * this.s.length;
            this.ml = (this.inMask(DataConsoleAtom.message)) * this.m.length;
            this.cl = (this.inMask(DataConsoleAtom.contest)) * this.c.length;
            //Длина фрагмента с учётом наложенной маски.
            //Очень удобно: когда нужно выдать следующий элемент промежутка
            //т.к. длины "ненужных" массивов обнулены, поэтому просто пишем "слияние" трёх массивов
            this.length = this.sl + this.ml + this.cl;
        },
        
        setMask : function(mask) { //ASK: loadMask?
            this.reset();
            this.changeMask(mask);
        },
        
        inMask : function(value) { //ASK: Fishy name.... How can it be named?
            return value & this.mask != 0 ? 1 : 0;
        },
        
        getNext : function(mask) {
            var di = DataConsoleDateInf;
            var s = (this.sc < this.sl ? this.s[this.sc].time : di);
            var m = (this.mc < this.ml ? this.m[this.mc].time : di);
            var c = (this.cc < this.cl ? this.c[this.cc].time : di);
            var result = String.min(String.min(s, m), c); result = (result == di ? undefined : result);
            if (!defined(result)) {return result;}
            
            if (this.s[this.sc].time == result) {return this.s[this.sc++];}
            else if (this.c[this.cc].time == result) {return this.c[this.cc++];}
            else if (this.m[this.mc].time == result) {return this.m[this.mc++];}
            
            return result;
        },
        
        getWholeFragment : function() {
            var result = [];
            for (var i = 0; i < this.length; i++) {
                result.push(this.getNext());
            }
        },
    }
);
