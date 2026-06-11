import UIKit

class HairAnalysisService {
    
    // OpenRouter API key
    private let apiKey = ""
    private let apiURL = "https://openrouter.ai/api/v1/chat/completions"
    
    private let systemPrompt = """
    You are receiving 4 images of the same person's hair from different angles:
      Image 1 — Front view (hairline & temples)
      Image 2 — Top/Crown view (crown area)
      Image 3 — Left side view
      Image 4 — Right side view

    Analyze ALL 4 images together and return ONE combined assessment.

    Density scale:
      91-100% → Excellent
      76-90%  → Good
      61-75%  → Moderate
      41-60%  → Low
      21-40%  → Very Low
      0-20%   → Severe

    Norwood Stages:
      Stage 1: No loss, full hairline
      Stage 2: Slight temple recession
      Stage 3: Deep temple recession
      Stage 3V: Crown thinning begins
      Stage 4: Clear recession + crown thinning
      Stage 5: Recession and crown nearly connected
      Stage 6: Large combined bald area
      Stage 7: Only side/back band remains

    Return ONLY this JSON, no extra text, no markdown, no code blocks:
    {
      "overall_density_percentage": <0-100>,
      "overall_density_label": "<label>",
      "norwood_stage": "<stage>",
      "norwood_description": "<one line>",
      "area_breakdown": {
        "front": { "density_percentage": <0-100>, "notes": "<one line>" },
        "crown": { "density_percentage": <0-100>, "notes": "<one line>" },
        "left":  { "density_percentage": <0-100>, "notes": "<one line>" },
        "right": { "density_percentage": <0-100>, "notes": "<one line>" }
    
    
    "hair_type": "<Straight/Wavy/Curly/Coily>",
    
      },
      "most_affected_area": "<front/crown/left/right>",
      "affected_areas": ["<area1>"],
      "confidence": "<High/Medium/Low>",
      "summary": "<3-4 sentences>",
      "tip": "<one non-medical tip>",
      "images_valid": {
        "front": <true/false>,
        "crown": <true/false>,
        "left":  <true/false>,
        "right": <true/false>
      }
    }
    """
    
    func analyse(
        front: UIImage,
        crown: UIImage,
        left: UIImage,
        right: UIImage
    ) async throws -> HairAnalysisResult {
        
        // Convert images to base64
        let frontB64 = imageToBase64(front)
        let crownB64 = imageToBase64(crown)
        let leftB64  = imageToBase64(left)
        let rightB64 = imageToBase64(right)
        
        // Build request body (OpenAI-compatible format)
        let body: [String: Any] = [
            "model": "openrouter/auto",
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image_url",
                            "image_url": ["url": "data:image/jpeg;base64,\(frontB64)"]
                        ],
                        [
                            "type": "image_url",
                            "image_url": ["url": "data:image/jpeg;base64,\(crownB64)"]
                        ],
                        [
                            "type": "image_url",
                            "image_url": ["url": "data:image/jpeg;base64,\(leftB64)"]
                        ],
                        [
                            "type": "image_url",
                            "image_url": ["url": "data:image/jpeg;base64,\(rightB64)"]
                        ],
                        [
                            "type": "text",
                            "text": "Analyse these 4 hair images and return only the JSON result."
                        ]
                    ]
                ]
            ]
        ]
        
        // Build request
        var request = URLRequest(url: URL(string: apiURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("https://hairanalysis.app", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("HairAnalysisTest", forHTTPHeaderField: "X-Title")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // DEBUG
        let rawString = String(data: data, encoding: .utf8) ?? "nil"
        print("RAW RESPONSE: \(rawString)")
        
        // Parse OpenAI-compatible response
        guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = response["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let text = message["content"] as? String else {
            throw NSError(domain: "HairAnalysis", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not parse OpenRouter response"])
        }
        
        print("AI TEXT: \(text)")
        
        // Clean response
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("CLEANED: \(cleaned)")
        
        guard let jsonData = cleaned.data(using: .utf8) else {
            throw NSError(domain: "HairAnalysis", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Could not convert response to data"])
        }
        
        do {
            let result = try JSONDecoder().decode(HairAnalysisResult.self, from: jsonData)
            return result
        } catch {
            print("DECODE ERROR: \(error)")
            print("FAILED JSON: \(cleaned)")
            throw NSError(domain: "HairAnalysis", code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Could not decode result: \(error.localizedDescription)"])
        }
    }
    
    private func imageToBase64(_ image: UIImage) -> String {
        let compressed = image.jpegData(compressionQuality: 0.5) ?? Data()
        return compressed.base64EncodedString()
    }
}

