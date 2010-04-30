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
        __constructor : function(since, to, s, m, c, tmstmp) {
            this.since = since;
            this.to = to;
            this.s = s; this.m = m; this.c = c; //submissions, messages, contests
            this.timestamp = tmstmp;
            this.reset();
            
            if (!defined(this.since)) {
                var currSince = DataConsoleDateInf;
                for (var i in s) {currSince = String.min(currSince, s[i])};
                for (var i in m) {currSince = String.min(currSince, m[i])};
                for (var i in c) {currSince = String.min(currSince, c[i])};
                this.since = currSince;
            }
            //фрагмент, который пришёл после прокрутки куда-то вниз, когда нам указали только верхнюю временную границу
            
            if (!defined(this.to)) {
                this.to = DataConsoleDateInf;
            }
            //top console
        },
        
        reset : function() {
            this.sc = 0; this.mc = 0; this.cc = 0; //counters
        },
        
        changeMask : function(mask) { //ASK: setMask?
            this.mask = mask;
            this.sl = (this.matchMask(DataConsoleAtom.submission)) * this.s.length;
            this.ml = (this.matchMask(DataConsoleAtom.message)) * this.m.length;
            this.cl = (this.matchMask(DataConsoleAtom.contest)) * this.c.length;
            //Длина фрагмента с учётом наложенной маски.
            //Очень удобно: когда нужно выдать следующий элемент промежутка
            //т.к. длины "ненужных" массивов обнулены, поэтому просто пишем "слияние" трёх массивов
            this.length = this.sl + this.ml + this.cl;
        },
        
        setMask : function(mask) { //ASK: loadMask?
            this.reset();
            this.changeMask(mask);
        },
        
        matchMask : function(value) { //ASK: Fishy name.... How can it be named?
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


const DataConsoleFragmentsSequence = $.inherit(
    {
        __constructor : function(since, to, s, m, c) {
            this.seq = [];
            this.reqs = [];
        },
        
        findNearestFragment: function(time) {
            var l = 0;
            var r = this.seq.length - 1;
            
            if (time >= this.seq[r].since) {
                return r;
            }
            //т.к. большинство запросов будут приходиться на top консоли,
            //проверяем, не нужно ли выдать top фрагмент
            r--;
            while (l+1 < r) {
                var q = Math.floor((l + r) / 2);
                if (this.seq[q].since <= time) {
                    l = q;
                } else {
                    r = q;
                }
            }
            //ну а иначе --- поиск ближайшего (в сторону убывания даты) фрагмента бинарным поиском
            r = l;
            //здесь r имеет смысл номера правого фрагмента, покрывающего наш запрос,
            //это как раз тот l который мы нашли: ближайщий, имеющий слева since
            if (this.seq[r].to < time) {
                reqs.push(new DataConsoleRequest.between(this.seq[r].to, time, false, true));
                //если попали между фрагментами, имеет смысл спросить данные с конца предыдущего фрагмента по указанное время 
            }
            if (r == 0) {
                if (this.seq[r].since > time) {
                    reqs.push(new DataConsoleRequest.before(time, true));
                    //мы попали в самый низкий фрагмент, пытаемся выяснить, что было до него
                } else {
                    reqs.push(new DataConsoleRequest.before(this.seq[r].since, false));
                    //или же мы вообще уехали далеко вниииииииз
                }
            }
            return r;
        },
        
        getLines : function(time, mask, quantity) {
            var r = this.findNearestFragment(time);
            var k = 0;
            this.seq[r].setMask(mask);
            var result = this.seq[r].getWholeFragment();
            if (result[0].time >= time) {
                var i = result.length - 1;
                while (result[i].time > time) {
                    result.pop();
                }
                //убить всё лишнее с конца
                while (result.length < quantity) {
                    this.loaded = false;
                    r--;
                    if (r < 0) {
                        return result;
                    } else {
                        reqs.push(new DataConsoleRequest.between(this.seq[r].to, this.seq[r+1].since, false, false));
                        //может быть что-то есть между уже сохранёнными фрагментами?
                        var l = this.seq[r].getWholeFragment();
                        result = l.append(result);
                    }
                }
            }
        },
        
        takeRequests : function() {
            var result = this.reqs;
            this.clearRequests();
            return result;
        },
        
        clearRequests : function() {
            this.reqs = [];
        }
    }
);


var DataConsoleRequest = {};

DataConsoleRequest.abstract = $.inherit(
    {
        get : function() {
            return result;
        },
    }
);

DataConsoleRequest.between = $.inherit(
     DataConsoleRequest.abstract,
     {
        __constructor : function(between, and, ge, le) {
            this.result = {
                'type' : 'between',                
                'between' : between,
                'and' : and,
                'l' : (le ? 'e' : 't'),
                'g' : (ge ? 'e' : 't'),
            };
        },
     }
);

DataConsoleRequest.before = $.inherit(
     DataConsoleRequest.abstract,
     {
        __constructor : function(before, le) {
            this.result = {
                'type' : 'before',                
                'before' : before,
                'l' : (le ? 'e' : 't'),
            };
        },
     }
);

DataConsoleRequest.top = $.inherit(
     DataConsoleRequest.abstract,
     {
        __constructor : function(time, before, le) {
            this.result = {
                'type' : 'top',
            };
        },
     }
);
