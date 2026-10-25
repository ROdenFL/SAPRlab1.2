`timescale 1ns/1ps
module TB;
    logic pclk;
    logic presetn;
    logic psel;
    logic penable;
    logic pwrite;
    logic [31:0] paddr;
    logic [31:0] pwdata;
    wire [31:0] prdata;
    wire pready;
    wire pslverr;

    parameter p_device_offset = 32'h7000_0000;

    parameter [31:0] p_student_number = 32'd2;       // номер в списке группы
    parameter [31:0] p_date           = 32'h25102026; // дата
    parameter [31:0] p_surname        = "Vany";      // первые 4 буквы фамилии
    parameter [31:0] p_name           = "Dani";      // первые 4 буквы имени

    logic [31:0] address;
    logic [31:0] data_to_device;
    logic [31:0] data_from_device;


    apb_slave DUT
    (
        .pclk(pclk), //синхросигнал
        .presetn, //сигнал сброса (инверсный)
        .paddr(paddr), //адрес обращения
        .pwdata(pwdata), //данные для записи
        .psel(psel), // признак выбора устройсва
        .penable(penable), //признак активной транзакции
        .pwrite(pwrite), // признак операции записи
        .pready(pready), // признак готовности от устройства
        .pslverr(pslverr), // опциональный сигнал: признак ошибки при обращении
        .prdata(prdata) // прочитанные данные
    );

    task apb_write(input [31:0] addr, [31:0] data);
        wait ((penable==0) && (pready == 0));
        @(posedge pclk);
        psel <= 1'b1;
        paddr[31:0] <= addr[31:0];
        pwdata[31:0] <= data[31:0];
        pwrite <= 1'b1;
        @(posedge pclk);
        penable <= 1'b1;
        @(posedge pclk);
        wait (pready == 1'b1);
        @(posedge pclk);
        psel <= 1'b0;
        penable <= 1'b0;
        pwrite <= 1'b0;
        @(posedge pclk);
    endtask

    task apb_read(input [31:0] addr, output logic [31:0] data);
        wait ((penable==0) && (pready == 0));
        @(posedge pclk);
        psel <= 1'b1;
        pwrite <= 1'b0;
        paddr[31:0] <= addr[31:0];
        @(posedge pclk);
        penable <= 1'b1;
        @(posedge pclk);
        wait (pready == 1'b1);
        @(posedge pclk);
        data[31:0]<=prdata[31:0];
        psel <= 1'b0;
        penable <= 1'b0;
        @(posedge pclk);
    endtask

    always
    #10ns pclk=~pclk;

    initial
    begin
        pclk=0;
        presetn=1'b1;

        psel='0;
        penable='0;
        pwrite='0;
        paddr='0;
        pwdata='0;
        repeat (5) @(posedge pclk);
        presetn=1'b0;
        repeat (5) @(posedge pclk);
        presetn=1'b1;
        repeat (5) @(posedge pclk);
        // --- запись ---
        apb_write(p_device_offset + 32'h0, p_student_number);
        apb_write(p_device_offset + 32'h4, p_date);
        apb_write(p_device_offset + 32'h8, p_surname);
        apb_write(p_device_offset + 32'hC, p_name);

        // --- чтение обратно и проверка ---
        apb_read(p_device_offset + 32'h0, data_from_device);
        $display("0x0: write %0d, read %0d  %s", p_student_number, data_from_device, (data_from_device == p_student_number) ? "OK" : "ERROR");
        apb_read(p_device_offset + 32'h4, data_from_device);
        $display("0x4: write 0x%h, read 0x%h  %s", p_date, data_from_device, (data_from_device == p_date) ? "OK" : "ERROR");
        apb_read(p_device_offset + 32'h8, data_from_device);
        $display("0x8: write 0x%h \"%s\", read 0x%h \"%s\"  %s", p_surname, p_surname, data_from_device, data_from_device, (data_from_device == p_surname) ? "OK" : "ERROR");
        apb_read(p_device_offset + 32'hC, data_from_device);
        $display("0xC: write 0x%h \"%s\", read 0x%h \"%s\"  %s", p_name, p_name, data_from_device, data_from_device, (data_from_device == p_name) ? "OK" : "ERROR");
        repeat (10) @(posedge pclk);
        $stop();
    end


    initial
    begin
        $monitor("APB IF state: PENABLE=%b PREADY=%b PADDR=0x%h PWDATA=0x%h PRDATA=0x%h", penable, pready, paddr, pwdata, prdata);
    end
endmodule
