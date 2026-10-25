`timescale 1ns/1ps
module TB2;
    logic pclk;
    logic presetn;

    // интерфейс пользователя мастера
    logic start;
    logic write;
    logic [31:0] addr;
    logic [31:0] wdata;
    wire busy;
    wire done;
    wire [31:0] rdata;
    wire err;

    // шина APB между мастером и слейвом
    wire [31:0] paddr;
    wire [31:0] pwdata;
    wire psel;
    wire penable;
    wire pwrite;
    wire pready;
    wire pslverr;
    wire [31:0] prdata;

    parameter p_device_offset = 32'h7000_0000;

    parameter [31:0] p_student_number = 32'd2;       // номер в списке группы
    parameter [31:0] p_date           = 32'h25102026; // дата
    parameter [31:0] p_surname        = "Vany";      // первые 4 буквы фамилии
    parameter [31:0] p_name           = "Dani";      // первые 4 буквы имени

    int errors;

    apb_master DUT_M
    (
        .pclk(pclk), //синхросигнал
        .presetn(presetn), //сигнал сброса (инверсный)
        .start(start), // запрос на транзакцию
        .write(write), // 1 - запись, 0 - чтение
        .addr(addr), // адрес обращения
        .wdata(wdata), // данные для записи
        .busy(busy), // транзакция выполняется
        .done(done), // транзакция завершена
        .rdata(rdata), // прочитанные данные
        .err(err), // признак ошибки
        .paddr(paddr),
        .pwdata(pwdata),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .pready(pready),
        .pslverr(pslverr),
        .prdata(prdata)
    );

    apb_slave DUT_S
    (
        .pclk(pclk),
        .presetn(presetn),
        .paddr(paddr),
        .pwdata(pwdata),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .pready(pready),
        .pslverr(pslverr),
        .prdata(prdata)
    );

    // одна транзакция через пользовательский интерфейс мастера
    task do_cmd(input logic w, input [31:0] a, input [31:0] d, output logic [31:0] r, output logic e);
        wait (!busy);
        @(posedge pclk);
        start <= 1'b1;
        write <= w;
        addr <= a;
        wdata <= d;
        @(posedge pclk);
        start <= 1'b0;
        do @(posedge pclk); while (!done);
        r = rdata;
        e = err;
    endtask

    task write_chk(input [31:0] a, input [31:0] d, input exp_err);
        logic [31:0] r;
        logic e;
        do_cmd(1'b1, a, d, r, e);
        if (e !== exp_err)
        begin
            errors++;
            $display("ERROR  write 0x%h <= 0x%h: err=%b, expected %b", a, d, e, exp_err);
        end
        else
            $display("OK     write 0x%h <= 0x%h (err=%b)", a, d, e);
    endtask

    task read_chk(input [31:0] a, input [31:0] exp_d, input exp_err);
        logic [31:0] r;
        logic e;
        do_cmd(1'b0, a, 32'h0, r, e);
        if (e !== exp_err || r !== exp_d)
        begin
            errors++;
            $display("ERROR  read  0x%h => 0x%h err=%b, expected 0x%h err=%b", a, r, e, exp_d, exp_err);
        end
        else
            $display("OK     read  0x%h => 0x%h (err=%b)", a, r, e);
    endtask

    always
    #10ns pclk=~pclk;

    initial
    begin
        pclk=0;
        presetn=1'b1;
        errors=0;

        start='0;
        write='0;
        addr='0;
        wdata='0;
        repeat (5) @(posedge pclk);
        presetn<=1'b0;
        repeat (5) @(posedge pclk);
        presetn<=1'b1;
        repeat (5) @(posedge pclk);

        // --- запись ---
        write_chk(p_device_offset + 32'h0, p_student_number, 1'b0);
        write_chk(p_device_offset + 32'h4, p_date,           1'b0);
        write_chk(p_device_offset + 32'h8, p_surname,        1'b0);
        write_chk(p_device_offset + 32'hC, p_name,           1'b0);

        // --- чтение обратно и проверка ---
        read_chk(p_device_offset + 32'h0, p_student_number, 1'b0);
        read_chk(p_device_offset + 32'h4, p_date,           1'b0);
        read_chk(p_device_offset + 32'h8, p_surname,        1'b0);
        read_chk(p_device_offset + 32'hC, p_name,           1'b0);

        // --- обращение по несуществующему адресу: слейв должен выставить ошибку ---
        write_chk(p_device_offset + 32'h10, 32'hDEAD_BEEF, 1'b1);
        read_chk (p_device_offset + 32'h14, 32'h0,         1'b1);

        // --- после ошибки pslverr сбрасывается, а данные регистров не пострадали ---
        read_chk(p_device_offset + 32'h0, p_student_number, 1'b0);
        read_chk(p_device_offset + 32'hC, p_name,           1'b0);

        repeat (10) @(posedge pclk);
        if (errors == 0)
            $display("TEST PASSED");
        else
            $display("TEST FAILED, errors: %0d", errors);
        $stop();
    end

    initial
    begin
        $monitor("APB IF state: PSEL=%b PENABLE=%b PWRITE=%b PREADY=%b PSLVERR=%b PADDR=0x%h PWDATA=0x%h PRDATA=0x%h",
                 psel, penable, pwrite, pready, pslverr, paddr, pwdata, prdata);
    end
endmodule
