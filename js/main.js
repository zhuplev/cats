var session;
 
var dataset, interface;


//можно было обойтись и без этого, т.е. просто тупо заводить объекты без функции, но тогда
//не понятно, что делать во время reload. А так мы бесплатно получаем reload и init в одном лице.
var startEvent = function() {
    alert('You must define startEvent which defines dataset and interface objects');
}


function init() {
    dataset = undefined;   //Сделано специально, на случай, если переменные присвоят ручками,
    interface = undefined; //не определив переменную startEvent.
    
    startEvent();
    
    if (!dataset || !interface) {
        alert('You must define dataset and interface objects');
    } else {
        dataset.setOnUpdateEvent(utils.delegate(interface, interface.onUpdate));
        dataset.setOnFirstUpdateEvent(utils.delegate(interface, interface.onFirstUpdate));
        interface.setDataset(dataset);
        
        dataset.start();
    }
}


function reloadPage() {
    init();
}