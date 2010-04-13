const InterfaceAbstract = $.inherit(
    {
        __constructor : function() {
          
        },
        
        setDataset : function(dataset) {
            this.dataset = dataset;
        },
        
        onUpdate : function() {
            alert('You must define onUpdate() event in your class');
        },
        
        onFirstUpdate : function() {
            alert('You can define onFirstUpdate() event in your class');
        },
        

    }
);