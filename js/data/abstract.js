const DataAbstract = $.inherit(
    {
        param : {}, //параметры, передающиеся отдельно в POST запросе
        json: {}, //JSON
        
        lastUpdateTimestamp : startLastUpdateTimestamp,
        
        setParam : function(key, value) {
            value = defined(value) ? value : 1;
            this.param[key] = value;
        },
        
        deleteParam : function(key) {
            delete(this.param[key]);
        },
        
        setJSON : function(key, value) {
            value = value || 1;
            this.json[key] = value;
        },
        
        deleteJSON : function(key) {
            delete(this.json[key]);
        },
        
        __constructor : function() {
            this.setParam('sid', session.sid);
            this.setParam('cid', session.cid);
            this.setParam('ajax');
        },
        
        getRequest : function() {
            var r = 'request={0}';
            for (var _ in this.param) {
                r += String.format(';{0}={1}', _, this.param[_]);
            }
            return String.format(r, $.toJSON(this.json));
        },
        
        setOnUpdateEvent : function(onUpdateEventDelegate) {
            this.interfaceUpdateEvent = onUpdateEventDelegate;
        },
        
        setOnFirstUpdateEvent : function(onUpdateFirstEventDelegate) {
            this.interfaceFirstUpdateEvent = onUpdateFirstEventDelegate;
        },
        
        start : function() {
            alert('You must define start() event in your data class');
        },
        
    }
);