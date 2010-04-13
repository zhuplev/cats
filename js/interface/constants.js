const submitStatus = {
    0 : {
        msg: "not processed",
        testNum: false,
        class: "submit_status_OK",
    },
    1 : {
        msg: "unhandled error",
        testNum: false,
        class: "submit_status_fatal_error",
    },
    2 : {
        msg: "install_processing",
        testNum: false,
        class: "submit_status_preparing",
    },
    3 : {
        msg: "testing",
        testNum: false,
        class: "submit_status_preparing",
    },
    10 : {
        msg: "solution accepted",
        testNum: false,
        class: "submit_status_OK",
    },
    101 : {
        msg: "solution rejected",
        testNum: false,
        class: "submit_status_error",
    },
    11 : {
        msg: "wrong answer",
        testNum: true,
        class: "submit_status_error",
    },
    12 : {
        msg: "presentation error",
        testNum: true,
        class: "submit_status_error",
    },
    13 : {
        msg: "time limit exceeded",
        testNum: true,
        class: "submit_status_error",
    },
    14 : {
        msg: "runtime errorr",
        testNum: true,
        class: "submit_status_error",
    },
    15 : {
        msg: "compilation error",
        testNum: false,
        class: "submit_status_error",
    },
    16 : {
        msg: "security violation",
        testNum: false,
        class: "submit_status_fatal_error",
    },
    17 : {
        msg: "memory limit exceeded",
        testNum: true,
        class: "submit_status_error",
    },
    18 : {
        msg: "ignore submit",
        testNum: false,
        class: "submit_status_ignore",
    },
};
