const DataConsoleAtom = {
    submission : 1 << 0,
    message : 1 << 1,
    contest : 1 << 2,
};


const DataConsoleDateInf = '9999-99-99';
const DataConsoleDateNegInf = '0000-00-00';


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
            this.console = [
                new DataConsoleFragmentVector('submissions', DataConsoleAtom.submission, this),
                new DataConsoleFragmentVector('messages', DataConsoleAtom.message, this),
                new DataConsoleFragmentVector('contests', DataConsoleAtom.contest, this),
            ];     
            this.dataType = {};
            this.userMask = 0;
            for (var i = 0; i < this.console.length; i++) {
                this.dataType[this.console[i].dataType] = this.console[i];
                this.userMask = this.userMask | this.console[i].mask;
            }
            this.userTime = null;
            this.userLength = ajaxConsoleStartUserLength;
            this.maxFragmentSize = null;
        },
        
        start : function() {
            this.makeAndShowConsole();
            var timer = utils.timer(utils.delegate(this, this.sendRequest), ajaxConsoleRequestInterval);
        },
        
        changeTime : function(newTime) {
            for (var i = 0; i < this.console.length; i++) {
                this.console[i].clearReqs(false);
            }
            if (newTime == null || newTime == undefined || newTime == '') {
                this.userTime = null;
            } else {
                this.userTime = newTime;
            }
            
            this.makeAndShowConsole();
        },
        
        getConsole : function() {
            return this.currentConsoleLines;
        },
        
        makeAndShowConsole : function() {
            var tmp = this.makeConsole(this.userTime, this.userMask, this.userLength);
            this.interfaceUpdateEvent();
        },
        
        makeConsole : function(time, mask, length) {
            var v = [];
            var result = [];
            this.currentConsoleLines = [];
            if (time == null) {
                time = DataConsoleDateInf;
            }
            //Выясняем что подходит под заказанную маску
            for (var i = 0; i < this.console.length; i++) {
                if (mask & this.console[i].mask) {
                    v.push(this.console[i]);
                }
            }
            //и уже бегаем только по тем массивам, которые нам нужны =)
            for (var i = 0; i < v.length; i++) {
                v[i].toNear(time, false);
            }
            for (var cntLine = 0; cntLine < length; cntLine++) {
                var end = true;
                var best = null;
                for (var i = 0; i < v.length; i++) {
                    var isEnd = v[i].end();
                    end = end && isEnd;
                    if (!isEnd && best == null) {
                        best = i;
                    }
                }
                if (end) {
                    break;
                }
                for (var i = 0; i < v.length; i++) {
                    if (!v[i].end() && v[i].getCurrLine().time > v[best].getCurrLine().time) {
                        best = i;
                    }
                }
                result.push(v[best].getCurrLine());
                v[best].toNextLine();
            }
            this.currentConsoleLines = result;
            return 1;
        },
        
        sendRequest : function() {
            this.json = {'fragments' : {}};
            for (var i = 0; i < this.console.length; i++) {
                var list = this.console[i].getReqs();
                if (list.length != 0) {
                    this.json.fragments[this.console[i].dataType] = list;
                }
            }
            if (this.maxFragmentSize == null) {
                this.json['fragment_size'] = 1;
            }
            //alert(this.getRequest());
            jQuery.ajax.post(utils.getMainURL(), this.getRequest(), utils.delegate(this, this.response));
        },
        
        response : function(dataResponse, textStatus, XMLHttpRequest) {
            this.serverTime = dataResponse.server_timestamp;
            this.updateIds(dataResponse, 'teams');
            this.updateIds(dataResponse, 'problems');
            var isModify = {};
            //инициализация isModify
            for (var i = 0; i < this.console.length; i++) {
                isModify[this.console[i].dataType] = true;
            }
            if (defined(dataResponse.console)) {
                var fr = dataResponse.console;
                if (fr.fragment_size) {
                    this.maxFragmentSize = fr.fragment_size;
                }
                fr = fr.fragments;
                if (defined(fr)) {
                    for (var i = 0;  i < fr.length; i++) {
                        var frdt = fr[i].data_type;
                        this.dataType[frdt].addFragment(this.serverTime, fr[i]);
                        isModify[frdt] = isModify[frdt] && fr[i].is_modify;
                    }
                }
            }
            for (var key in isModify) {
                if (!isModify[key]) {
                    this.dataType[key].clearReqs(true);
                } else {
                    this.dataType[key].clearReqs(false);
                }
            }
            //$('#message_to_admin').html(XMLHttpRequest.responseText);
            this.makeAndShowConsole();
        },
        
        updateIds : function(dataResponse, idType) {
            var drc = dataResponse.console;
            if (defined(drc) && defined(drc[idType])) {
                for (var key in drc[idType]) {
                    this.ids[idType][key] = drc[idType][key];
                }
            }
        },
        
    }
);


const DataConsoleFragmentVector = $.inherit(
    {
        __constructor : function(dataType, currMask, console) {
            this.dataType = dataType;
            this.mask = currMask;
            this.console = console;
            this.i = 0;
            this.seq = [new DataConsoleFragment(startLastUpdateTimestamp, 'top', null, null, [])];
            this.reqs = [];
            this.updateOnly = false;
        },
        
        addFragment : function(timestamp, fr) {
            var newFr = new DataConsoleFragment(timestamp, fr.type, fr.since, fr.to, fr.seq)
            if (fr.is_modify == 1) {
                this.addNewFragment(timestamp, newFr);
            } else {
                this.modifyExistingFragment(timestamp, newFr);
            }
        },
        
        newFragment : function(timestamp, fr) {
            return new DataConsoleFragment(timestamp, fr.type, fr.since, fr.to, fr.seq);
        },
        
        addNewFragment : function(timestamp, fr) {
            if (fr.type == 'top') {
                this.modifyExistingFragment(timestamp, fr);
            } else {
                for (var i = 0; i < this.seq.length; i++) {
                    if (fr.to <= this.seq[i].since) {
                        this.seq.insertAfter(i-1, this.newFragment(timestamp, fr));
                        break;
                    }
                }
            }
        },
        
        modifyExistingFragment : function(timestamp, fr) {
            //fr.type == 'top' проверять смысла нет, потому что может прийти ответ типа top, но с фильтром
            //очевидно, что может быть далеко не top в смысле полной консоли, поэтому сравниваем даты
            var l1 = this.seq.length - 1;
            if (fr.since > this.seq[l1].since) { 
                this.mergeAndSplit(l1, timestamp, fr.seq);
                if (this.seq[l1].since == DataConsoleDateNegInf) {
                    this.seq[l1].since = fr.since;
                }
            } else {
                //здесь код для самого общего случая: пришёл большой страшный фрагмент,
                //который может пересекаться как угодно с имеющимися.
                //Например фильтр или резкое появление чего-нибудь в консоли (появился "скрытый" участник и т.д.)
                for (var i = 0; i < this.seq.length; i++) {
                    var currSeq = this.seq[i];
                    if (currSeq.since <= fr.since && fr.to <= currSeq.to) {
                        //если остаток нового фрагмента полностью входит в имеющийся
                        this.mergeAndSplit(i, timestamp, fr.seq);
                        break;
                    }
                    //TODO
                }
            }
        },
        
        mergeAndSplit : function(num, timestamp, seq) {
            this.seq[num].merge(timestamp, seq);
            this.splitFragment(num);
        },
        
        splitFragment : function(num) {
            var mfs = this.console.maxFragmentSize;
            if (this.seq[num].seq.length > mfs) {
                var cf = this.seq[num];
                var cs = this.seq[num].seq;
                var ls = []; var rs = [];
                for (var i = 0; i < mfs; i++) {
                    ls.push(cs[i]);
                }
                for (var i = mfs; i < cs.length; i++) {
                    rs.push(cs[i]);
                }
                var lf = new DataConsoleFragment(
                    cf.timestamp,
                    cf.type == 'before' ? 'before' : 'between',
                    cf.since,
                    ls[mfs - 1].time,
                    ls
                );
                var rf = new DataConsoleFragment(
                    cf.timestamp,
                    cf.type == 'top' ? 'top' : 'between',
                    dateToTimestamp(timestampToDate(ls[mfs - 1].time).msecAdd(1)),
                    //начинаем фрагмент сразу же на окончанием левого фрагмента
                    cf.to,
                    rs
                );
                this.seq[num] = lf;
                this.seq.insertAfter(num, rf);
                this.splitFragment(num + 1);
            }
        },
        
        findNear : function(time) {
            var length = this.seq.length;
            if (!this.updateOnly && this.seq[0].since > time) {
                this.reqs.push(new DataUpdateConsoleRequest.before(
                    startLastUpdateTimestamp,
                    time,
                    true,
                    true
                ));
                return -2;
            }
            //большинство запросов будет на top, поэтому проверим-ка ручками:
            if (length > 0 && this.seq[length-1].since <= time) {
                return length-1;
            }
            var result = 0;
            while (result < length-1 && this.seq[result].to < time) {
                result++;
            }
            if (!this.updateOnly && this.seq[result].since > time) {
                //между фрагментами:
                result--;
                this.reqs.push(new DataUpdateConsoleRequest.between(
                    startLastUpdateTimestamp,
                    this.seq[result].to,
                    this.seq[result+1].since,
                    false,
                    false,
                    true
                ));
            }
            return result;
        },
        
        toNear : function(time, updateOnly) {
            this.i = this.findNear(time, updateOnly);
            if (this.i >= 0) {
                this.seq[this.i].toNear(time, updateOnly);
                this.reqs.push(this.seq[this.i].getUpdateRequest());
            }
        },
        
        end : function() {
            return this.i < 0 || this.i == 0 && this.seq[this.i].end();
        },
        
        toNextLine : function()  {
            this.seq[this.i].toNextLine();
            if (this.seq[this.i].end()) {
                this.i--;
                if (this.i >= 0) {
                    this.seq[this.i].setBegin();
                    //перепрыгиваем через фрагменты, а вдруг там есть данные?
                    if (!this.updateOnly) {
                        this.reqs.push(new DataUpdateConsoleRequest.between(
                            startLastUpdateTimestamp,
                            this.seq[this.i].to,
                            this.seq[this.i+1].since,
                            false,
                            false,
                            true
                        ));
                    }
                    this.reqs.push(this.seq[this.i].getUpdateRequest());
                }  else {
                    this.reqs.push(new DataUpdateConsoleRequest.before(
                        startLastUpdateTimestamp,
                        this.seq[this.i+1].since,
                        false,
                        true
                    ));
                }
            }
        },
        
        getCurrLine : function() {
            return this.seq[this.i].getCurrLine();
        },
        
        getReqs : function() {
            var result = [];
            for (var i = 0; i < this.reqs.length; i++) {
                var curr = this.reqs[i].get();
                var add = false;
                if (!defined(curr.since)) {
                    add = true;
                } else {
                    var cs = timestampToDate(curr.since).msecAdd(1);
                    var ct = timestampToDate(curr.to);
                    add = cs < ct;
                }
                if (add) {
                    result.push(curr);
                    //Добавляем только те запросы, since и to у которых отличаются больше чем на 1 миллисекунду
                }
            }
            return result;
        },
        
        clearReqs : function(updateOnly) {
            this.reqs = [];
            this.updateOnly = updateOnly;
        },
    }
);


const DataConsoleFragment = $.inherit(
    {
        __constructor : function(timestamp, type, since, to, seq) {
            this.timestamp = timestamp;
            this.type = type;
            this.since = since;
            this.to = to;
            this.seq = seq;
            if (type == 'top') {
                if (seq.length == 0) {
                    this.since = DataConsoleDateNegInf;
                } else {
                    this.since = seq[0].time;
                }
                this.to = DataConsoleDateInf;
            }
            this.i = seq.length == 0 ? -1 : 0;
        },
        
        setBegin : function() {
            this.i = this.seq.length - 1;
        },
        
        end : function() { //end-of-fragment
            return this.i < 0;
        },
        
        toNextLine : function()  {
            --this.i;
        },
        
        getCurrLine : function() {
            return this.seq[this.i];
        },
        
        findNear : function(time) {
            if (this.since > time) {
                return -2;
            }
            if (this.to < time) {
                return -1
            }
            var result = this.seq.length;
            do {
                result--;
            } while (result > 0 && this.seq[result].time > time);
            return result;
        },
        
        toNear : function(time, updateOnly) {
            this.i = this.findNear(time, updateOnly);
        },
        
        getUpdateRequest : function() {
            if (this.type == 'top') {
                return new DataUpdateConsoleRequest.top(this.timestamp);
            } else {
                //просим только обновление
                return new DataUpdateConsoleRequest.between(this.timestamp, this.since, this.to, true, true, false);
            }
        },
        
        merge : function(timestamp, newSeq) {
            var result = [];
            var seq = this.seq;
            for (var j = 0; j < newSeq.length; j++) {
                for (var i = 0; i < seq.length; i++) {
                    if (seq[i].time > newSeq[j].time) { break; }
                    if (seq[i].time == newSeq[j].time && seq[i].id == newSeq[j].id) {
                        seq[i] = newSeq[j];
                        newSeq[j]['vis'] = 1;
                        break;
                    }
                }
            }
            var i = 0;
            var j = 0;
            while (i < seq.length && j < newSeq.length) {
                if (newSeq[j]['vis'] == 1) { j++; continue; }
                if (seq[i].time < newSeq[j].time) {
                    result.push(seq[i]);
                    i++;
                 } else {
                    result.push(newSeq[j]);
                    j++;
                 }
            }
            while (i < seq.length) {
                result.push(seq[i++]);
            }
            while (j < newSeq.length) {
                result.push(newSeq[j++]);
            }
            this.timestamp = timestamp;
            this.seq = result;
        },
    }
);


var DataUpdateConsoleRequest = {};

DataUpdateConsoleRequest.abstract = $.inherit(
    {
        get : function() {
            this.result.is_modify = this.result.is_modify ? 1 : 0;
            return this.result;
        },
    }
);

DataUpdateConsoleRequest.between = $.inherit(
     DataUpdateConsoleRequest.abstract,
     {
        __constructor : function(luts, since, to, ge, le, isModify) {
            this.result = {
                'last_update_timestamp' : luts,
                'type' : 'between',                
                'since' : since,
                'to' : to,
                'l' : (le ? 'e' : 't'),
                'g' : (ge ? 'e' : 't'),
                'is_modify' : isModify,
            };
        },
     }
);

DataUpdateConsoleRequest.before = $.inherit(
     DataUpdateConsoleRequest.abstract,
     {
        __constructor : function(luts, to, le, isModify) {
            this.result = {
                'last_update_timestamp' : luts,
                'type' : 'before',                
                'to' : to,
                'l' : (le ? 'e' : 't'),
                'is_modify' : isModify,
            };
        },
     }
);

DataUpdateConsoleRequest.top = $.inherit(
     DataUpdateConsoleRequest.abstract,
     {
        __constructor : function(luts) {
            this.result = {
                'last_update_timestamp' : luts,
                'type' : 'top',
                'is_modify' : true, //Патамушта top консоли должен обновляться всегда,
            };
        },
     }
);
