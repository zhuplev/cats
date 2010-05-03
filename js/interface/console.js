var InterfaceConsoleLine = {};

InterfaceConsoleLine.abstract = $.inherit(
    {
        __constructor : function(dataset, data) {
            this.dataset = dataset;
            this.data = data;
        },
        
        html : function() {
            var rtype = ['submit', 'question', 'message', 'broadcast', 'contestStart', 'contestFinish'][this.data.rtype];
            return String.format('<tr><td>{0}</td><td>{1}</td></tr>', this.data.time, rtype);
        },
    }
);
    
InterfaceConsoleLine.status = $.inherit(
    InterfaceConsoleLine.abstract,
    {
        html : function() {
            var st = submitStatus[this.data.submit_state];
            return String.format('<tr><td>{0}</td><td>{1}: {2} - {3}{4}</td></tr>',
                this.data.time,
                this.dataset.ids.teams[this.data.team_id],
                this.dataset.ids.problems[this.data.problem_id],
                st.msg,
                st.testNum ? ' on test #' + this.data.failed_test : ''
            );
        },
    }
);
    
InterfaceConsoleLine.question = $.inherit(
    InterfaceConsoleLine.abstract,
    {
        html : function() {
            return String.format('<tr><td>{0}</td><td>{1}: {2} - {3}</td></tr>',
                this.data.time,
                this.dataset.ids.teams[this.data.team_id],
                this.data.question,
                this.data.answer
            );
        }
    }
);

InterfaceConsoleLine.message = $.inherit(
    InterfaceConsoleLine.abstract,
    {
        html : function() {
            return String.format('<tr><td>{0}</td><td>JURY : {1} - "{2}"</td></tr>',
                this.data.time,
                this.dataset.ids.teams[this.data.team_id],
                this.data.message
            );
        }
    }
);

InterfaceConsoleLine.broadcast = $.inherit(
    InterfaceConsoleLine.abstract,
    {
        html : function() {
            return String.format('<tr><td>{0}</td><td> </b>BROADCAST</b> : {1}</td></tr>',
                this.data.time,
                this.data.message
            );
        }
    }
);

InterfaceConsoleLine.contestStart = $.inherit(
    InterfaceConsoleLine.abstract,
    {
        html : function() {
            return String.format('<tr><td>{0}</td><td> </b>contest start</b> : {1}</td></tr>',
                this.data.time,
                this.data.title
            );
        }
    }
);

InterfaceConsoleLine.contestFinish = $.inherit(
    InterfaceConsoleLine.abstract,
    {
        html : function() {
            return String.format('<tr><td>{0}</td><td> </b>contest finish</b> : {1}</td></tr>',
                this.data.time,
                this.data.title
            );
        }
    }
);


const InterfaceConsole = $.inherit(
    InterfaceAbstract,
    {
        __constructor : function() {
          this.__base();
        },
        
        setDataset : function(dataset) {
            this.__base(dataset);
            this.dataset.problemlistChangeEvent = utils.delegate(this, this.problemlistChange);
        },
        
        onUpdate : function() {
            var consoleContent = '';
            var currentConsole = dataset.getConsole();
            if (currentConsole.length == 0) {
                consoleContent = String.format('<img src="{0}"/>', ajaxPageLoaderImg);
            } else {
                for (var i = 0; i < currentConsole.length; i++) {
                    var component = new this.__self.Line[currentConsole[i].rtype](dataset, currentConsole[i]);
                    consoleContent += component.html();
                }
            }    
            $('#refreshable_content').html(this.__self.consoleHeader + consoleContent + this.__self.consoleFooter);
            $('#server_time').html(this.dataset.serverTime);
        },
        
        onFirstUpdate : function() {
            this.problemlistChange();
        },
        
        problemlistChange : function() {
            
        },
        
        showQuestionForm : function() {
            
        },
        
        hideQuestionForm : function() {
            
        },
        
    },
    {
        Line : [
            InterfaceConsoleLine.status,
            InterfaceConsoleLine.question,
            InterfaceConsoleLine.message,
            InterfaceConsoleLine.broadcast,
            InterfaceConsoleLine.contestStart,
            InterfaceConsoleLine.contestFinish,
        ],
        consoleHeader : '<table>',
        consoleFooter : '</table>',
    }
);
