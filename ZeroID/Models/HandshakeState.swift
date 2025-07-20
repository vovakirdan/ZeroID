import Foundation

enum HandshakeOfferState: Equatable {
    case offerGenerated(String)  // оффер готов, показываем поле и копируем
    case waitingForAnswer        // ждем вставки answer
}

enum HandshakeAnswerState: Equatable {
    case waitingOffer            // ждет вставки offer
    case answerGenerated(String) // answer готов, показываем поле и копируем
} 