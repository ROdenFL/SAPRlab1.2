module top
#(
    parameter [31:0] p_device_offset  = 32'h7000_0000,
    parameter [31:0] p_student_number = 32'd2,        // номер в списке группы
    parameter [31:0] p_date           = 32'h25102026, // дата
    parameter [31:0] p_surname        = "Vany",       // первые 4 буквы фамилии
    parameter [31:0] p_name           = "Dani"        // первые 4 буквы имени
)
(
    input pclk, //синхросигнал
    input presetn, //сигнал сброса (инверсный)
    output logic done, // вся последовательность выполнена
    output logic pass // все записи прошли без ошибок и все прочитанные значения совпали с записанными
);

    // шина APB между мастером и слейвом
    logic [31:0] paddr;
    logic [31:0] pwdata;
    logic psel;
    logic penable;
    logic pwrite;
    logic pready;
    logic pslverr;
    logic [31:0] prdata;

    // интерфейс пользователя мастера
    logic start;
    logic cmd_write;
    logic [31:0] cmd_addr;
    logic [31:0] cmd_wdata;
    logic m_busy;
    logic m_done;
    logic m_err;
    logic [31:0] m_rdata;

    apb_master u_apb_master
    (
        .pclk(pclk),
        .presetn(presetn),
        .start(start),
        .write(cmd_write),
        .addr(cmd_addr),
        .wdata(cmd_wdata),
        .busy(m_busy),
        .done(m_done),
        .rdata(m_rdata),
        .err(m_err),
        .paddr(paddr),
        .pwdata(pwdata),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .pready(pready),
        .pslverr(pslverr),
        .prdata(prdata)
    );

    apb_slave u_apb_slave
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

    enum logic [1:0] {
        SEQ_START,
        SEQ_WAIT,
        SEQ_DONE
    } seq_st;

    logic [2:0] step;
    logic [31:0] exp_data; // значение, соответствующее текущему смещению

    always @*
    begin
        case (step[1:0])
            2'd0: exp_data = p_student_number;
            2'd1: exp_data = p_date;
            2'd2: exp_data = p_surname;
            default: exp_data = p_name;
        endcase

        cmd_write = !step[2];
        cmd_addr = p_device_offset + {28'h0, step[1:0], 2'b00};
        cmd_wdata = exp_data;
    end

    always @(posedge pclk)
        if (!presetn)
            begin
                seq_st <= SEQ_START;
                step <= 3'd0;
                start <= 1'b0;
                done <= 1'b0;
                pass <= 1'b1;
            end
        else
        begin
            case (seq_st)
                SEQ_START:
                begin
                    // запрос на 1 такт, мастер в этот момент свободен
                    start <= 1'b1;
                    seq_st <= SEQ_WAIT;
                end

                SEQ_WAIT:
                begin
                    start <= 1'b0;
                    if (m_done)
                    begin
                        // ошибка шины или несовпадение прочитанного значения
                        if (m_err || (step[2] && (m_rdata != exp_data)))
                            pass <= 1'b0;

                        if (step == 3'd7)
                        begin
                            done <= 1'b1;
                            seq_st <= SEQ_DONE;
                        end
                        else
                        begin
                            step <= step + 3'd1;
                            seq_st <= SEQ_START;
                        end
                    end
                end

                SEQ_DONE:
                begin
                    // последовательность выполнена, ждём сброса
                end

                default:
                begin
                    seq_st <= SEQ_START;
                end
            endcase
        end

endmodule