`default_nettype none

/*
 * MODULE: drone_core
 * DESCRIPTION: Cœur logique de la puce ASIC pour drone agricole.
 * Conçu pour être synthétisé via OpenLane / Efabless Caravel.
 */
module drone_core (
    input wire clk,           // Horloge système
    input wire rst_n,         // Reset actif à l'état bas

    // Capteurs (Entrées numériques venant de l'ADC ou de GPIOs)
    input wire [7:0] altitude,      // Altitude en décimètres (20 = 2.0m)
    input wire [7:0] tank_level,    // Niveau de la cuve (0 à 100%)
    input wire system_en,           // Activation globale du système

    // Actionneurs (Sorties numériques vers les relais/MOSFETs)
    output reg alert_empty_tank,    // Alerte cuve vide (LED / Buzzer / Télémetrie)
    output reg valve_open,          // Ouverture de la valve
    output wire pump_pwm_out        // Signal PWM matériel pour la pompe
);

    reg [7:0] pwm_counter;
    reg [7:0] pwm_duty;
    reg pump_enable;

    // ----------------------------------------------------
    // Générateur PWM Matériel (Hardware PWM Generator)
    // ----------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_counter <= 8'd0;
        end else begin
            pwm_counter <= pwm_counter + 1;
        end
    end
    
    // Le signal PWM est généré si la pompe est activée et que le compteur est sous le rapport cyclique
    assign pump_pwm_out = (pump_enable && (pwm_counter < pwm_duty)) ? 1'b1 : 1'b0;

    // ----------------------------------------------------
    // Logique de Contrôle de Pulvérisation
    // ----------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pump_enable <= 0;
            valve_open <= 0;
            pwm_duty <= 8'd0;
            alert_empty_tank <= 0;
        end else if (system_en) begin
            if (tank_level == 8'd0) begin
                // Sécurité: Si la cuve est vide
                alert_empty_tank <= 1;
                pump_enable <= 0;
                valve_open <= 0;
                pwm_duty <= 8'd0;
            end else begin
                alert_empty_tank <= 0;
                
                // Conditions idéales : Altitude entre 2.0m (20) et 5.0m (50)
                if (altitude >= 8'd20 && altitude <= 8'd50) begin
                    pump_enable <= 1;
                    valve_open <= 1;
                    pwm_duty <= 8'd128; // Rapport cyclique de 50% (128 / 256)
                end else begin
                    pump_enable <= 0;
                    valve_open <= 0;
                    pwm_duty <= 8'd0;
                end
            end
        end else begin
            // Système désactivé
            pump_enable <= 0;
            valve_open <= 0;
            pwm_duty <= 8'd0;
            alert_empty_tank <= 0;
        end
    end

endmodule
