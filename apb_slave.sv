module apb_slave
(
    input pclk, //синхросигнал
    input presetn, //сигнал сброса (инверсный)
    input [31:0] paddr, //адрес обращения
    input [31:0] pwdata, //данные для записи
    input psel, // признак выбора устройсва
    input penable, //признак активной транзакции
    input pwrite, // признак операции записи
    output logic pready, // признак готовности от устройства
    output logic pslverr, // опциональный сигнал: признак ошибки при обращении
    output logic [31:0] prdata // прочитанные данные
);

    logic [31:0] reg_num;                 // 0x0 - номер в списке группы
    logic [31:0] reg_date;                // 0x4 - дата дд.мм.гггг (BCD)
    logic [31:0] reg_surname;             // 0x8 - 4 буквы фамилии (ASCII)
    logic [31:0] reg_name;                // 0xC - 4 буквы имени (ASCII)

    //APB FSM
    enum logic [1:0] {
        APB_SETUP,
        APB_W_ENABLE,
        APB_R_ENABLE
    } apb_st;

    always @(posedge pclk)
        if (!presetn)
            begin
                prdata <= '0;
                pslverr <= 1'b0;
                pready <= 1'b0;
                reg_num <= 32'h0;
                reg_date <= 32'h0;
                reg_surname <= 32'h0;
                reg_name <= 32'h0;
                apb_st <= APB_SETUP;
            end
        else
        begin

        case(apb_st)
            APB_SETUP:
            begin: apb_setup_st
                // clear the prdata and error
                prdata <= '0;
                pslverr <= 1'b0;
                pready <= 1'b0;

                // Move to ENABLE when the psel is asserted
                if (psel && !penable)
                begin
                    if (pwrite == 1'b1)
                        begin
                            apb_st <= APB_W_ENABLE;
                        end
                    else
                        begin
                            apb_st <= APB_R_ENABLE;
                        end
                end
            end: apb_setup_st

            APB_W_ENABLE:
            begin: apb_w_en_st
                // decode address and write
                if (psel && penable && pwrite)
                begin
                    pready <= 1'b1;
                    case (paddr[7:0])
                        8'h0: 
                        begin
                        // запись в регистр со смещением 0
                        reg_num <= pwdata;
                        end
                        8'h4: 
                        begin
                        // запись в регистр со смещением 4
                        reg_date <= pwdata;
                        end
                        8'h8: 
                        begin
                        // запись в регистр со смещением 8
                        reg_surname <= pwdata;
                        end
                        8'hC: 
                        begin
                        // запись в регистр со смещением 0xC
                        reg_name <= pwdata;
                        end
                        default:
                        begin
                            pslverr <= 1'b1;
                        end
                    endcase
                    apb_st <= APB_SETUP;
                end
            end: apb_w_en_st

            APB_R_ENABLE:
                begin: apb_r_en_st
                if (psel && penable && !pwrite)
                begin
                    pready <= 1'b1;
                    case (paddr[7:0])
                        8'h0: 
                        begin
                        // чтение из регистра со смещением 0
                        prdata[31:0] <= reg_num[31:0];
                        end
                        8'h4: 
                        begin
                        // чтение из регистра со смещением 4
                        prdata[31:0] <= reg_date[31:0];
                        end
                        8'h8: 
                        begin
                        // чтение из регистра со смещением 8
                        prdata[31:0] <= reg_surname[31:0];
                        end
                        8'hC: 
                        begin
                        // чтение из регистра со смещением 0xC
                        prdata[31:0] <= reg_name[31:0];
                        end
                        default:
                        begin
                            pslverr <= 1'b1;
                        end
                    endcase
                    apb_st <= APB_SETUP;
                end
            end: apb_r_en_st


            default:
                begin
                    pslverr <= 1'b1;
                end
        endcase



    end // закончился блок внутри always

endmodule
