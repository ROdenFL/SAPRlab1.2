`timescale 1ns/1ps
module TB3;
    logic pclk;
    logic presetn;
    wire done;
    wire pass;

    top DUT
    (
        .pclk(pclk), //синхросигнал
        .presetn(presetn), //сигнал сброса (инверсный)
        .done(done), // последовательность выполнена
        .pass(pass) // результат проверки
    );

    always
    #10ns pclk=~pclk;

    initial
    begin
        pclk=0;
        presetn=1'b1;
        repeat (5) @(posedge pclk);
        presetn<=1'b0;
        repeat (5) @(posedge pclk);
        presetn<=1'b1;

        wait (done);
        repeat (2) @(posedge pclk);

        $display("0x0: reg_num     = %0d", DUT.u_apb_slave.reg_num);
        $display("0x4: reg_date    = 0x%h", DUT.u_apb_slave.reg_date);
        $display("0x8: reg_surname = 0x%h \"%s\"", DUT.u_apb_slave.reg_surname, DUT.u_apb_slave.reg_surname);
        $display("0xC: reg_name    = 0x%h \"%s\"", DUT.u_apb_slave.reg_name, DUT.u_apb_slave.reg_name);
        $display("TEST %s", pass ? "PASSED" : "FAILED");
        $stop();
    end

    // защита от зависания
    initial
    begin
        #100us;
        if (!done)
        begin
            $display("TIMEOUT: done not reached");
            $stop();
        end
    end

    initial
    begin
        $monitor("APB IF state: PSEL=%b PENABLE=%b PWRITE=%b PREADY=%b PSLVERR=%b PADDR=0x%h PWDATA=0x%h PRDATA=0x%h",
                 DUT.psel, DUT.penable, DUT.pwrite, DUT.pready, DUT.pslverr, DUT.paddr, DUT.pwdata, DUT.prdata);
    end
endmodule