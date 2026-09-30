.pragma library

// Search of the mod list and the store. Every word of the query has to match, in any order. A word matches when it is
// part of the text, or when its letters appear in the text in the same order starting at the beginning of a word:
// "ww" and "waw" find "Warwick", "kp" finds "Keypad Phone". Case, accents and punctuation do not count.

var cache = {}
var cacheSize = 0
// The words of the last query, which is matched against every mod or skin in a row.
var lastQuery = null
var lastWords = []

// Letters and digits; the Qt 5 JavaScript engine does not know \p{L}, so anything outside the punctuation and symbol
// blocks counts as a letter.
function isLetter(c) {
    if (c < "\u0080") {
        return (c >= "a" && c <= "z") || (c >= "0" && c <= "9")
    }
    return !(c <= "¿" || c === "×" || c === "÷" || (c >= " " && c <= "⯿")
             || (c >= "　" && c <= "〿") || (c >= "＀" && c <= "／"))
}

// The text in lower case without accents, spaces or punctuation ("Kai'Sa" is "kaisa", "İspanyolca" is "ispanyolca"),
// and for every letter whether a word starts there: after a space or punctuation, at a capital after a small letter
// ("KeypadPhone") and where digits begin or end.
function scan(text) {
    let letters = ""
    let starts = []
    let gap = true
    let kind = ""
    let source = String(text).replace(/ı/g, "i").normalize("NFD")
    for (let i = 0; i < source.length; i++) {
        let c = source[i]
        if (c >= "̀" && c <= "ͯ") {
            continue
        }
        let lower = c.toLowerCase()
        if (!isLetter(lower)) {
            gap = true
            continue
        }
        let now = c >= "0" && c <= "9" ? "digit" : c !== lower ? "upper" : "lower"
        let start = gap || (now === "upper" && kind === "lower") || ((now === "digit") !== (kind === "digit"))
        for (let k = 0; k < lower.length; k++) {
            letters += lower[k]
            starts.push(start && k === 0)
        }
        gap = false
        kind = now
    }
    return { "letters": letters, "starts": starts }
}

function prepare(text) {
    let prepared = cache[text]
    if (prepared === undefined) {
        if (cacheSize > 20000) {
            cache = {}
            cacheSize = 0
        }
        prepared = cache[text] = scan(text)
        cacheSize++
    }
    return prepared
}

// 3 at the start of a word, 2 inside one, between 1 and 2 for an abbreviation (the closer its letters, the higher)
// and 0 when the word does not match.
function wordScore(word, target) {
    let letters = target.letters
    let at = letters.indexOf(word)
    if (at !== -1) {
        for (let i = at; i !== -1; i = letters.indexOf(word, i + 1)) {
            if (target.starts[i]) {
                return 3
            }
        }
        return 2
    }
    let best = 0
    for (let from = letters.indexOf(word[0]); from !== -1; from = letters.indexOf(word[0], from + 1)) {
        if (!target.starts[from]) {
            continue
        }
        let end = from
        for (let k = 1; k < word.length && end !== -1; k++) {
            end = letters.indexOf(word[k], end + 1)
        }
        if (end === -1) {
            // A later start has even fewer letters after it.
            break
        }
        best = Math.max(best, 1 + word.length / (end - from + 1))
    }
    return best
}

function queryWords(query) {
    if (query !== lastQuery) {
        lastQuery = query
        lastWords = []
        let parts = String(query).split(/\s+/)
        for (let i = 0; i < parts.length; i++) {
            let word = scan(parts[i]).letters
            if (word !== "") {
                lastWords.push(word)
            }
        }
    }
    return lastWords
}

// How well the query matches the text: 0 when it does not, higher for better matches, 1 for an empty query. Words
// found only in the optional extra text (a description) count as weak matches.
function score(query, text, extra) {
    let words = queryWords(query)
    if (words.length === 0) {
        return 1
    }
    let target = prepare(text)
    let total = 0
    for (let i = 0; i < words.length; i++) {
        let result = wordScore(words[i], target)
        if (result === 0 && extra && prepare(extra).letters.indexOf(words[i]) !== -1) {
            result = 0.5
        }
        if (result === 0) {
            return 0
        }
        total += result
    }
    return total
}
