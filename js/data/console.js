const DataConsoleAtom = {
    submission : 1 << 0,
    message : 1 << 1,
    contest : 1 << 2,
};
//Как бэ не настаиваю на именно таком задании параметров.
//Поэтому вся проверка "маски" вынесена в отдельные функции, при желании можно переписать.


const DataConsoleDateInf = '9';
const DataConsoleDateNegInf = '0';


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
        __constructor : function(dataType, since, to, seq) {
            this.dataType = dataType;
            this.since = since;
            this.to = to;
            this.seq = seq;
            if (dataType == 'top') {
                this.since = seq[0].time;
                this.to = DataConsoleDateInf;
            }
            this.length = seq.length;
            this.i = 0;
        },
        
        setBegin : function() {
            this.i = this.length;
        },
        
        end : function() { //end-of-fragment
            return this.i < 0;
        },
        
        nextLine : function()  {
            return this.seq[--this.i];
        },
        
        currLine : function() {
            return this.seq[this.i];
        },
        
        findNear : function(time) {
            if (this.since > time) {
                return -2;
            }
            if (this.to < time) {
                return -1
            }
            var result = 0;
            result = this.length;
            do {
                result--;
            } while (this.seq[this.result].time > time);
            //TODO: написать бинарный поиск!
            return result;
        },
        
        toNear : function(time) {
            this.i = this.findNear();
        }
    }
);


const DataConsoleFragmentVector = $.inherit(
    {
        __constructor : function(dataType) {
            this.dataType = dataType;
            this.length = -1;
            this.i = 0;
            this.seq = [];
            this.reqs = [];
        },
        
        findNear : function(time) {
            if (this.seq[0].since > time) {
                this.reqs.push(new DataConsoleRequest.before(this.dataType, time, true));
                return -2;
            }
            //большинство запросов будет на top, поэтому проверим-ка ручками:
            if (this.seq[this.length-1].since <= time) {
                return this.length-1;
            }
            var result = 0;
            while (result < this.length-1 && this.seq[this.result].to < time) {
                result++;
            }
            if (this.seq[result].since > time) {
                //между фрагментами:
                result--;
                this.reqs.push(new DataConsoleRequest.between(this.dataType, this.seq[result].to, this.seq[result+1].since, false, false));
            }
            //TODO: написать бинарный поиск!
            return result;
        },
        
        nextLine : function()  {
            if (this.seq[this.i].end()) {
                this.seq[--this.i].setBegin();
            }
            return this.seq[this.i].nextLine();
        },
        
        currLine : function() {
            return this.seq[this.i].currLine();
        },
        
        toNear : function(time) {
            this.i = this.findNear(time);
            this.seq[this.i].toNear(time);
        },
        
        end : function() {
            this.i < 0;
        },
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
        __constructor : function(data_type, since, to, ge, le) {
            this.result = {
                'data_type' : data_type,
                'type' : 'between',                
                'since' : since,
                'to' : to,
                'l' : (le ? 'e' : 't'),
                'g' : (ge ? 'e' : 't'),
            };
        },
     }
);

DataConsoleRequest.before = $.inherit(
     DataConsoleRequest.abstract,
     {
        __constructor : function(data_type, to, le) {
            this.result = {
                'data_type' : data_type,
                'type' : 'before',                
                'to' : to,
                'l' : (le ? 'e' : 't'),
            };
        },
     }
);

DataConsoleRequest.top = $.inherit(
     DataConsoleRequest.abstract,
     {
        __constructor : function(data_type, time, before, le) {
            this.result = {
                'data_type' : data_type,
                'type' : 'top',
            };
        },
     }
);
