// Item de sequencia do Memory Agent: um "pacote de RF" emulado em nivel
// logico (Tag ID + status da checagem de CRC), conforme a Secao 3.3 da
// monografia. E o que as sequences (diretas ou constrained-random) geram e
// o driver reativo entrega ao nucleo pelos registradores mapeados em
// memoria (ADDR_TAG_ID / ADDR_CRC_STATUS).
class rf_pkt_item extends uvm_sequence_item;

    rand bit [31:0] tag_id;
    rand bit [31:0] crc_status;

    constraint c_crc_valido {
        crc_status inside {CRC_VALID, CRC_INVALID_1BIT, CRC_INVALID_MULTIBIT};
    }

    `uvm_object_utils_begin(rf_pkt_item)
        `uvm_field_int(tag_id,     UVM_ALL_ON)
        `uvm_field_int(crc_status, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "rf_pkt_item");
        super.new(name);
    endfunction

    function string convert2string();
        string crc_s;
        case (crc_status)
            CRC_VALID:            crc_s = "VALIDO";
            CRC_INVALID_1BIT:     crc_s = "INVALIDO_1BIT";
            CRC_INVALID_MULTIBIT: crc_s = "INVALIDO_MULTI";
            default:              crc_s = "DESCONHECIDO";
        endcase
        return $sformatf("tag_id=0x%08x crc=%s", tag_id, crc_s);
    endfunction

endclass : rf_pkt_item
