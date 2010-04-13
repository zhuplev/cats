var InterfaceConsoleComponent = {};

InterfaceConsoleComponent.abstract = $.inherit(
    {
        __constructor : function(data) {
            this.data = data;
        },
        
        html : function() {
            var rtype = ['submit', 'question', 'message', 'broadcast', 'contestStart', 'contestFinish'][this.data.rtype];
            return String.format('<tr><td>{0}</td><td>{1}</td></tr>', this.data.time, rtype);
        }
    }
);
    
InterfaceConsoleComponent.status = $.inherit(
    InterfaceConsoleComponent.abstract,
    {
            
    }
);
    
InterfaceConsoleComponent.question = $.inherit(
    InterfaceConsoleComponent.abstract,
    {
            
    }
);

InterfaceConsoleComponent.message = $.inherit(
    InterfaceConsoleComponent.abstract,
    {
            
    }
);

InterfaceConsoleComponent.broadcast = $.inherit(
    InterfaceConsoleComponent.abstract,
    {
            
    }
);

InterfaceConsoleComponent.contestStart = $.inherit(
    InterfaceConsoleComponent.abstract,
    {
            
    }
);

InterfaceConsoleComponent.contestFinish = $.inherit(
    InterfaceConsoleComponent.abstract,
    {
            
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
            for (var i in dataset.current) {
                var component = new this.__self.Component[dataset.current[i].rtype](dataset.current[i]);
                consoleContent += component.html();
            }
            $('#refreshable_content').html(this.__self.consoleHeader + consoleContent + this.__self.consoleFooter);
            $('#server_time').html(this.dataset.time);
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
        Component : [
            InterfaceConsoleComponent.status,
            InterfaceConsoleComponent.question,
            InterfaceConsoleComponent.message,
            InterfaceConsoleComponent.broadcast,
            InterfaceConsoleComponent.contestStart,
            InterfaceConsoleComponent.contestFinish,
        ],
        consoleHeader : '<table>',
        consoleFooter : '</table>',
    }
);


    /*{
        //список параметров, общих для всех видов rtype, являются обязательными
        //commonParamList : ['time', 'id', 'last_console_update'],

        rObject : [
            //список параметров, которые будут вытаскиваться из JSON для каждого типа rtype
            //paramList -- обязательные параметры для всех типою юзеров
            //в случае их отсутствия громко кричим и показываем ошибку
            //остальные -- опциональные, в случае их отсутствия, никто не знает, что будет
            {
                /*paramList : ['problem_id', 'team_id', 'submit_status'],
                paramOptList : ['failed_test'],
                paramRootListAdd : ['contest_id'],
                paramJuryListAdd : ['last_ip_short', 'last_ip'],
                component : utils.delegate(InterfaceConsoleComponent, InterfaceConsoleComponent.status),
            },
            {
                /*paramList : ['question_text', 'clarified', 'team_id', 'answer_text'],
                paramRootListAdd : ['contest_id'],
                paramJuryListAdd : ['last_ip_short', 'last_ip'],
                component : utils.delegate(InterfaceConsoleComponent, InterfaceConsoleComponent.question),
            },
            {
                /*paramList : ['message_text', 'team_id'],
                paramRootListAdd : ['contest_id'],
                paramJuryListAdd : ['last_ip_short', 'last_ip'],
                component : utils.delegate(InterfaceConsoleComponent, InterfaceConsoleComponent.message),
            },
            {
//                 paramList : ['message_text'],
                component : utils.delegate(InterfaceConsoleComponent, InterfaceConsoleComponent.broadcast),
            },
            {
//                paramList : ['contest_title', 'is_official'],
                component : utils.delegate(InterfaceConsoleComponent, InterfaceConsoleComponent.contestStart),
            },
            {
//                paramList : ['contest_title', 'is_official'],
                component : utils.delegate(InterfaceConsoleComponent, InterfaceConsoleComponent.contestFinish),
            },
        ],
    }*/