#include <cctype>
#include <fstream>
#include <iostream>
#include <string>
#include <unordered_map>
#include <vector>

namespace {

bool starts_with_equate(const std::string& line, const std::string& symbol)
{
    if (line.rfind(symbol, 0) != 0) {
        return false;
    }

    if (line.size() <= symbol.size() ||
        !std::isspace(static_cast<unsigned char>(line[symbol.size()]))) {
        return false;
    }

    return line.find(".equ", symbol.size()) != std::string::npos;
}

bool source_has_equate(const std::vector<std::string>& lines, const std::string& symbol)
{
    for (const auto& line : lines) {
        if (starts_with_equate(line, symbol)) {
            return true;
        }
    }

    return false;
}

std::string global_label(const std::string& line)
{
    if (line.empty() ||
        (!std::isalpha(static_cast<unsigned char>(line[0])) && line[0] != '_')) {
        return {};
    }

    std::size_t index = 1;
    while (index < line.size() &&
           (std::isalnum(static_cast<unsigned char>(line[index])) ||
            line[index] == '_')) {
        ++index;
    }

    if (index < line.size() && line[index] == ':') {
        return line.substr(0, index);
    }

    return {};
}

bool has_review_comment(const std::vector<std::string>& lines, const std::string& table)
{
    for (const auto& line : lines) {
        const auto comment = line.find(';');
        if (comment != std::string::npos &&
            line.find(table, comment) != std::string::npos) {
            return true;
        }
    }

    return false;
}

void require_source_equate(
    std::vector<std::string>& errors,
    const std::vector<std::string>& lines,
    const std::string& symbol)
{
    if (!source_has_equate(lines, symbol)) {
        errors.push_back("missing symbolic opcode metadata '" + symbol + "'");
    }
}

void require_block_contains(
    std::vector<std::string>& errors,
    const std::unordered_map<std::string, std::string>& blocks,
    const std::string& table,
    const std::string& description,
    const std::vector<std::string>& needles)
{
    const auto block = blocks.find(table);
    const auto& text = block == blocks.end() ? std::string{} : block->second;

    for (const auto& needle : needles) {
        if (text.find(needle) == std::string::npos) {
            errors.push_back(description);
            return;
        }
    }
}

} // namespace

int main(int argc, char* argv[])
{
    if (argc != 2) {
        std::cerr << "usage: opcode-checker <monitor.asm>\n";
        return 2;
    }

    std::ifstream input(argv[1], std::ios::binary);
    if (!input) {
        std::cerr << "monitor source does not exist: " << argv[1] << "\n";
        return 2;
    }

    std::vector<std::string> lines;
    std::string line;
    while (std::getline(input, line)) {
        if (!line.empty() && line.back() == '\r') {
            line.pop_back();
        }
        lines.push_back(line);
    }

    const std::vector<std::string> required_tables = {
        "mnemonics",
        "mnemonic_modes",
        "op_tbl",
        "op30_idx",
        "opa0_idx",
        "brbit_idx",
        "op80_idx",
    };

    std::unordered_map<std::string, bool> seen;
    std::unordered_map<std::string, std::string> blocks;
    for (const auto& table : required_tables) {
        seen[table] = false;
    }

    std::string section;
    for (const auto& current_line : lines) {
        const auto label = global_label(current_line);
        if (!label.empty()) {
            if (seen.find(label) != seen.end()) {
                section = label;
                seen[label] = true;
            } else if (!section.empty()) {
                section.clear();
            }
        }

        if (!section.empty()) {
            blocks[section] += current_line;
            blocks[section] += '\n';
        }
    }

    std::vector<std::string> errors;

    for (const auto& table : required_tables) {
        if (!seen[table]) {
            errors.push_back("missing EVSBUG12-derived table label '" + table + "'");
        }

        if (!has_review_comment(lines, table)) {
            errors.push_back("missing review comment for EVSBUG12-derived table '" +
                             table + "'");
        }
    }

    for (const auto& symbol : {
             "op_adc_imm", "op_add_imm", "op_and_imm", "op_asl_dir",
             "op_bcc", "op_brset0", "op_bset0", "op_lda_imm",
             "op_sta_base", "op_wait", "op_adc_idx", "op_brset_idx",
             "op_bset_idx", "op_fcb_idx", "op_lda_idx", "op_unused_idx",
         }) {
        require_source_equate(errors, lines, symbol);
    }

    for (const auto& symbol : {
             "_inh", "_bit_dir", "_rel", "_idx", "_bad", "_mem",
             "_imm_mem", "_bit_rel",
         }) {
        require_source_equate(errors, lines, symbol);
    }

    require_block_contains(
        errors,
        blocks,
        "mnemonics",
        "mnemonic text should use high-bit terminators instead of fixed strings",
        {"msg_end"});
    require_block_contains(
        errors,
        blocks,
        "mnemonics",
        "mnemonic text should be translated to local lower-case style",
        {"\"ad\""});
    require_block_contains(
        errors,
        blocks,
        "mnemonic_modes",
        "mnemonic mode table should name immediate/memory classes",
        {"_imm_mem", "|"});
    require_block_contains(
        errors,
        blocks,
        "mnemonic_modes",
        "mnemonic mode table should name bit-relative classes",
        {"_bit_rel", "|"});
    require_block_contains(
        errors,
        blocks,
        "op_tbl",
        "opcode table should use named opcode equates",
        {"op_adc_imm"});
    require_block_contains(
        errors,
        blocks,
        "op_tbl",
        "opcode table should include the wait opcode metadata",
        {"op_wait"});
    require_block_contains(
        errors,
        blocks,
        "op30_idx",
        "30-7f index table should use mnemonic index equates",
        {"op_neg_idx"});
    require_block_contains(
        errors,
        blocks,
        "op30_idx",
        "30-7f index table should preserve EVSBUG12 lsl mnemonic selection",
        {"op_lsl_idx"});
    require_block_contains(
        errors,
        blocks,
        "op30_idx",
        "30-7f index table should mark unused entries symbolically",
        {"op_unused_idx"});
    require_block_contains(
        errors,
        blocks,
        "opa0_idx",
        "a0-af index table should use arithmetic/load/store indices",
        {"op_sub_idx", "op_stx_idx"});
    require_block_contains(
        errors,
        blocks,
        "brbit_idx",
        "branch/bit index table should use branch and bit indices",
        {"op_brset_idx", "op_bih_idx"});
    require_block_contains(
        errors,
        blocks,
        "op80_idx",
        "80-9f index table should use inherent opcode indices",
        {"op_rti_idx", "op_txa_idx"});

    if (!errors.empty()) {
        std::cerr << "monitor opcode table audit failed:\n";
        for (const auto& error : errors) {
            std::cerr << "  - " << error << "\n";
        }
        return 1;
    }

    return 0;
}
