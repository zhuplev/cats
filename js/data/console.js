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
            var timer = utils.timer(utils.delegate(this, this.sendRequest), 5000);
        },
        
        sendFisrtRequest : function() {
            jQuery.ajax.post(utils.getMainURL(), this.getRequest(), utils.delegate(this, this.firstResponse));
            this.json = {};
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
            //$('#message_to_admin').html(XMLHttpRequest.responseText);
            this.interfaceUpdateEvent();
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
 