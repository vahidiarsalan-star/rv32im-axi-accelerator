// Include inside a test module defining clk, uart_rx_pin, uart_tx_pin, UART_DIV.
task automatic send_byte(input [7:0] value);
    integer bit_number;
    begin
        @(negedge clk); uart_rx_pin = 0;
        repeat (UART_DIV) @(negedge clk);
        for (bit_number = 0; bit_number < 8; bit_number = bit_number + 1) begin
            uart_rx_pin = value[bit_number];
            repeat (UART_DIV) @(negedge clk);
        end
        uart_rx_pin = 1;
        repeat (UART_DIV) @(negedge clk);
    end
endtask

task automatic send_text(input string value);
    integer index;
    begin
        for (index = 0; index < value.len(); index = index + 1)
            send_byte(value[index]);
    end
endtask

reg [7:0] observed_byte;
reg [255:0] transcript_tail = 0;
integer prompt_count = 0;
integer tx_count = 0;
integer tx_bit;
// Independent observer samples the serial output pin, including its stop bit.
initial forever begin
    @(negedge uart_tx_pin);
    repeat (UART_DIV + UART_DIV/2) @(negedge clk);
    for (tx_bit = 0; tx_bit < 8; tx_bit = tx_bit + 1) begin
        observed_byte[tx_bit] = uart_tx_pin;
        repeat (UART_DIV) @(negedge clk);
    end
    if (uart_tx_pin !== 1'b1) $fatal(1, "UART TX stop bit invalid");
    transcript_tail = {transcript_tail[247:0], observed_byte};
    tx_count = tx_count + 1;
    if (observed_byte == ">") prompt_count = prompt_count + 1;
    $write("%c", observed_byte);
end

function automatic response_matches(input [255:0] tail, input string response);
    reg [255:0] expected;
    reg [255:0] mask;
    integer character;
    begin
        expected = 0;
        for (character = 0; character < response.len(); character = character + 1)
            expected = (expected << 8) | response[character];
        mask = {256{1'b1}} >> (256 - 8*response.len());
        response_matches = (tail & mask) == expected;
    end
endfunction
