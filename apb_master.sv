module apb_master
(
    input pclk, //синхросигнал
    input presetn, //сигнал сброса (инверсный)

    input start, // запрос на транзакцию, принимается когда busy == 0
    input write, // 1 - запись, 0 - чтение
    input [31:0] addr, // адрес обращения
    input [31:0] wdata, // данные для записи
    output logic busy, // транзакция выполняется
    output logic done, // импульс на 1 такт: транзакция завершена, rdata и err действительны
    output logic [31:0] rdata, // прочитанные данные (для чтения)
    output logic err, // признак ошибки (pslverr) завершённой транзакции

    // шина APB
    output logic [31:0] paddr, // адрес обращения
    output logic [31:0] pwdata, // данные для записи
    output logic psel, // признак выбора устройства
    output logic penable, // признак активной транзакции
    output logic pwrite, // признак операции записи
    input pready, // признак готовности от устройства
    input pslverr, // признак ошибки при обращении
    input [31:0] prdata // прочитанные данные
);

    //APB FSM
    enum logic [1:0] {
        M_IDLE,
        M_SETUP,
        M_ACCESS
    } apb_st;

    assign busy = (apb_st != M_IDLE);

    always @(posedge pclk)
        if (!presetn)
            begin
                paddr <= '0;
                pwdata <= '0;
                psel <= 1'b0;
                penable <= 1'b0;
                pwrite <= 1'b0;
                rdata <= '0;
                err <= 1'b0;
                done <= 1'b0;
                apb_st <= M_IDLE;
            end
        else
        begin
            done <= 1'b0;

            case (apb_st)
                M_IDLE:
                begin
                    // принимаем запрос: выставляем адрес, данные и psel
                    if (start)
                    begin
                        paddr <= addr;
                        pwdata <= wdata;
                        pwrite <= write;
                        psel <= 1'b1;
                        penable <= 1'b0;
                        apb_st <= M_SETUP;
                    end
                end

                M_SETUP:
                begin
                    // через такт после psel выставляем penable (фаза ACCESS)
                    penable <= 1'b1;
                    apb_st <= M_ACCESS;
                end

                M_ACCESS:
                begin
                    // ждём pready от слейва, при необходимости неограниченно долго
                    if (pready)
                    begin
                        if (!pwrite)
                            rdata <= prdata;
                        err <= pslverr;
                        done <= 1'b1;
                        psel <= 1'b0;
                        penable <= 1'b0;
                        apb_st <= M_IDLE;
                    end
                end

                default:
                begin
                    psel <= 1'b0;
                    penable <= 1'b0;
                    apb_st <= M_IDLE;
                end
            endcase
        end

endmodule