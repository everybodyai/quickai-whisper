// quickai-whisper: what a person said, written down by whisper.cpp, for QuickAI.
//
// QuickAI starts it with a speech model and keeps it running while the microphone is used: the model is loaded once,
// and each recording is a request on its input, answered with one line of JSON on its output. It opens no file but the
// model and no connection; what it hears is not kept.
//
//   quickai-whisper --model <file.bin> [--threads N] [--verbose]
//   quickai-whisper --version
//   quickai-whisper --system-info
//
// The protocol (README.md):
//   started:  {"ready":true,"version":"0.2.0","whisper":"1.8.3","system":"AVX = 1 | ..."}
//             or {"ready":false,"error":"..."}, and it ends
//   request:  a line `transcribe <id> <samples> <language>` (a whisper language code, or `auto`), then <samples>
//             samples of 16 kHz mono as 32-bit floats, little-endian, -1 to 1
//   answer:   {"id":<id>,"text":"...","language":"en","ms":812} or {"id":<id>,"error":"..."}
//   `quit`, or the end of the input, ends it.

#include "whisper.h"

#include <algorithm>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#endif

#ifndef QUICKAI_WHISPER_VERSION
#define QUICKAI_WHISPER_VERSION "0.0.0"
#endif

namespace {

constexpr int RATE = 16000;
// the most samples a request may carry: ten minutes
constexpr long MOST_SAMPLES = 600L * RATE;

bool verbose = false;

void quiet_log(enum ggml_log_level, const char * text, void *) {
    if (verbose) {
        fputs(text, stderr);
    }
}

// `text` as a JSON string, quotes and all
std::string json(const std::string & text) {
    std::string out = "\"";
    for (unsigned char c : text) {
        switch (c) {
            case '"': out += "\\\""; break;
            case '\\': out += "\\\\"; break;
            case '\n': out += "\\n"; break;
            case '\r': out += "\\r"; break;
            case '\t': out += "\\t"; break;
            default:
                if (c < 0x20) {
                    char buf[8];
                    snprintf(buf, sizeof buf, "\\u%04x", c);
                    out += buf;
                } else {
                    out += static_cast<char>(c);
                }
        }
    }
    return out + "\"";
}

void say(const std::string & line) {
    fputs(line.c_str(), stdout);
    fputc('\n', stdout);
    fflush(stdout);
}

// a line of the input, without its end; false at the end of the input
bool read_line(std::string & line) {
    line.clear();
    int c;
    while ((c = getc(stdin)) != EOF) {
        if (c == '\n') {
            if (!line.empty() && line.back() == '\r') {
                line.pop_back();
            }
            return true;
        }
        line += static_cast<char>(c);
        if (line.size() > 4096) {
            return false;
        }
    }
    return !line.empty();
}

std::string written_down(whisper_context * ctx, const std::vector<float> & samples, const std::string & language,
                         int threads, std::string & heard_language) {
    // too short to be words (a click of the button): nothing was said
    if (samples.size() < static_cast<size_t>(RATE / 4)) {
        return "";
    }
    whisper_full_params p = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    p.greedy.best_of = 1;
    p.language = language.c_str();
    p.translate = false;
    p.no_context = true;
    p.no_timestamps = true;
    p.suppress_blank = true;
    p.suppress_nst = true;
    p.print_progress = false;
    p.print_realtime = false;
    p.print_special = false;
    p.print_timestamps = false;
    p.n_threads = threads;
    // the encoder's window: for English, fitted to what was said and not under 15 s (750 frames, 50 a second), which
    // is twice as quick as its whole 30 s and as accurate; for every other language, and when the language is to be
    // told, the whole 30 s it was trained on. A window under 30 s makes it repeat a phrase until it stops, or write
    // made-up words, in other languages: measured on Common Voice sentences of 3 to 7 s with the small model, Hindi
    // went from 176 characters wrong in a hundred (7.7 s) to 43 (15 s) and 24 (30 s), Urdu from 45 to 16.
    const float seconds = static_cast<float>(samples.size()) / RATE;
    if (seconds < 29.0f) {
        if (language == "en") {
            p.audio_ctx = std::clamp(static_cast<int>(seconds * 50.0f) + 64, 750, 1500);
        }
        // what a person says at once is one piece
        p.single_segment = true;
    }
    // what it decodes badly (repeating itself, or unsure of every word) is decoded again at a higher temperature, as
    // whisper does by default; and no piece longer than a long sentence or two
    p.temperature_inc = 0.2f;
    p.max_tokens = 160;
    if (whisper_full(ctx, p, samples.data(), static_cast<int>(samples.size())) != 0) {
        throw std::runtime_error("the speech could not be written down");
    }
    std::string text;
    const int n = whisper_full_n_segments(ctx);
    for (int i = 0; i < n; ++i) {
        // a segment whisper thinks is not speech (the room) is left out
        if (whisper_full_get_segment_no_speech_prob(ctx, i) > 0.8f) {
            continue;
        }
        text += whisper_full_get_segment_text(ctx, i);
    }
    const int lang = whisper_full_lang_id(ctx);
    const char * name = lang >= 0 ? whisper_lang_str(lang) : nullptr;
    heard_language = name ? name : "";
    return text;
}

int usage(int code) {
    fputs("quickai-whisper " QUICKAI_WHISPER_VERSION ": what a person said, written down by whisper.cpp, for QuickAI.\n"
          "\n"
          "  quickai-whisper --model <file.bin> [--threads N] [--verbose]\n"
          "  quickai-whisper --version\n"
          "  quickai-whisper --system-info\n"
          "\n"
          "It reads requests on its input and answers each with a line of JSON (README.md).\n",
          code == 0 ? stdout : stderr);
    return code;
}

}  // namespace

int main(int argc, char ** argv) {
#ifdef _WIN32
    // the samples are bytes: no translation of line ends on either side
    _setmode(_fileno(stdin), _O_BINARY);
    _setmode(_fileno(stdout), _O_BINARY);
#endif
    std::string model;
    int threads = static_cast<int>(std::min(8u, std::max(1u, std::thread::hardware_concurrency())));
    for (int i = 1; i < argc; ++i) {
        const std::string arg = argv[i];
        if (arg == "--version") {
            printf("quickai-whisper %s (whisper.cpp %s)\n", QUICKAI_WHISPER_VERSION, whisper_version());
            return 0;
        } else if (arg == "--system-info") {
            printf("%s\n", whisper_print_system_info());
            return 0;
        } else if (arg == "--model" && i + 1 < argc) {
            model = argv[++i];
        } else if (arg == "--threads" && i + 1 < argc) {
            threads = std::max(1, atoi(argv[++i]));
        } else if (arg == "--verbose") {
            verbose = true;
        } else if (arg == "-h" || arg == "--help") {
            return usage(0);
        } else {
            fprintf(stderr, "quickai-whisper: %s is not an option\n\n", arg.c_str());
            return usage(2);
        }
    }
    if (model.empty()) {
        return usage(2);
    }
    whisper_log_set(quiet_log, nullptr);

    whisper_context_params cp = whisper_context_default_params();
    cp.use_gpu = false;
    whisper_context * ctx = whisper_init_from_file_with_params(model.c_str(), cp);
    if (ctx == nullptr) {
        say("{\"ready\":false,\"error\":" + json("the speech model could not be loaded: " + model) + "}");
        return 1;
    }
    say(std::string("{\"ready\":true,\"version\":") + json(QUICKAI_WHISPER_VERSION) + ",\"whisper\":" +
        json(whisper_version()) + ",\"system\":" + json(whisper_print_system_info()) + "}");

    std::string line;
    std::vector<float> samples;
    while (read_line(line)) {
        if (line.empty()) {
            continue;
        }
        if (line == "quit") {
            break;
        }
        char verb[16] = {0};
        char language[16] = {0};
        long long id = 0;
        long count = 0;
        if (sscanf(line.c_str(), "%15s %lld %ld %15s", verb, &id, &count, language) != 4 ||
            strcmp(verb, "transcribe") != 0) {
            // a line that is not a request: what follows it cannot be told from samples
            say("{\"id\":null,\"error\":" + json("not a request: " + line.substr(0, 80)) + "}");
            break;
        }
        if (count < 0 || count > MOST_SAMPLES) {
            say("{\"id\":" + std::to_string(id) + ",\"error\":\"too many samples\"}");
            break;
        }
        samples.resize(static_cast<size_t>(count));
        if (count > 0 && fread(samples.data(), sizeof(float), samples.size(), stdin) != samples.size()) {
            say("{\"id\":" + std::to_string(id) + ",\"error\":\"the samples ended early\"}");
            break;
        }
        const std::string lang = language;
        if (lang != "auto" && whisper_lang_id(lang.c_str()) < 0) {
            say("{\"id\":" + std::to_string(id) + ",\"error\":" + json("no language " + lang) + "}");
            continue;
        }
        const auto started = std::chrono::steady_clock::now();
        try {
            std::string heard;
            const std::string text = written_down(ctx, samples, lang, threads, heard);
            const long ms = static_cast<long>(std::chrono::duration_cast<std::chrono::milliseconds>(
                                                  std::chrono::steady_clock::now() - started)
                                                  .count());
            say("{\"id\":" + std::to_string(id) + ",\"text\":" + json(text) + ",\"language\":" +
                (heard.empty() ? std::string("null") : json(heard)) + ",\"ms\":" + std::to_string(ms) + "}");
        } catch (const std::exception & e) {
            say("{\"id\":" + std::to_string(id) + ",\"error\":" + json(e.what()) + "}");
        }
    }
    whisper_free(ctx);
    return 0;
}
