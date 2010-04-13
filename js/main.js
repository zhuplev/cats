var session;
 
var dataset, interface;


//����� ���� �������� � ��� �����, �.�. ������ ���� �������� ������� ��� �������, �� �����
//�� �������, ��� ������ �� ����� reload. � ��� �� ��������� �������� reload � init � ����� ����.
var startEvent = function() {
    alert('You must define startEvent which defines dataset and interface objects');
}


function init() {
    dataset = undefined;   //������� ����������, �� ������, ���� ���������� �������� �������,
    interface = undefined; //�� ��������� ���������� startEvent.
    
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