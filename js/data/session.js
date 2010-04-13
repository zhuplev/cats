const Session = $.inherit(
    {
        __constructor : function(isRoot, isJury, isTeam) {
            this.sid = window.location.href.match(/sid=(\w*)/)[1];
            this.cid = window.location.href.match(/cid=(\d+)/)[1];
            this.isRoot = isRoot;
            this.isJury = isJury;
            this.isTeam = isTeam;
        },
    
    }
);