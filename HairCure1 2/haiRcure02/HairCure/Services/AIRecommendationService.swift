import UIKit

class AIRecommendationService {
    
    static let shared = AIRecommendationService()
    
    private let apiKey = Config.openRouterAPIKey
    private let apiURL = "https://openrouter.ai/api/v1/chat/completions"
    
    private let systemPrompt = """
    You are an expert trichologist, dermatologist, and wellness coach specializing in male hair health and lifestyle-based hair recovery.
    
    You will receive the user's hair analysis details and their answers to the onboarding lifestyle questions. You must analyze these parameters in light of the clinical and scientific research guidelines below to generate an extremely personalized 1-week recovery plan.
    
    SCIENTIFIC & CLINICAL RESEARCH GUIDELINES:
    1. Sleep Hours (PSQI Scale & Trüeb 2015):
       - Less than 6 hours: Causes severe impairment and cortisol spikes that trigger telogen effluvium (follicle shedding).
       - 6-7 hours: Moderate sleep impairment.
       - 7-8 hours: WHO/NHS optimal range for cellular repair.
       - More than 8 hours: Can correlate with elevated cortisol (Motivala 2008).
       Tailor the MindEase routines to prioritize stress reduction and sleep-hygiene if sleep is under 7 hours.
    
    2. Diet Quality (Almohanna et al. 2019 & Rushton 2002):
       - Skipping meals / Junk food: High probability of iron, zinc, or biotin deficiencies, triggering hair thinning.
       - Highlight iron/zinc/biotin rich foods in the diet recommendations if their diet quality is poor.
       
    3. Hair Washing Frequency (Ranganathan & Mukhopadhyay 2010):
       - Daily: Strips natural sebum, disrupts the scalp microbiome.
       - Every 2-3 days: Consensus optimal frequency for healthy sebum balance.
       - Once a week or less: High risk of product buildup, sebum crystallization, and follicle blockage.
       Include scalp hygiene frequency adjustments in their daily routine based on their current wash habits.
       
    4. Physical Profile & Activity (EFSA 2010 & Mifflin-St Jeor):
       - Use Age, Height, Weight, and Activity Level to contextually frame hydration targets (minimum 35ml per kg) and calorie targets.
       
    5. Scalp Condition & Norwood Stage:
       - Dandruff: Target scalp microbiome with zinc and probiotics.
       - Dry scalp: Target hydration and healthy fats (Omega-3s, Vitamin A).
       - Oily scalp: Regulate sebum with Vitamin B6, zinc, and antioxidants.
       - Inflammation: Focus on anti-inflammatory diets and soothing scalp routines.
    
    The plan MUST specify:
      1. What to eat (diet & hair nutrition targeting biotin, zinc, iron, or sebum regulation).
      2. What to do in MindEase (stress management, yoga, or relaxing sound exercises).
      3. What to do in Hair Insights (tailored scalp washing, hair oiling, remedies, and massage routines).
    
    You must output ONLY a valid JSON object matching the schema below. Do not wrap it in code blocks or write any markdown. Do not include any text before or after the JSON.
    
    JSON Schema:
    {
      "planTitle": "<Catchy name, e.g. 'Deep Scalp Renewal' or 'Sebum Balance & Stress Recovery'>",
      "planSummary": "<A supportive 2-3 sentence overview of their situation, weak points, and focus areas>",
      "dietRecommendation": "<Overview of nutritional priorities for their hair and scalp type>",
      "recommendedFoods": ["<Food 1>", "<Food 2>", "<Food 3>", "<Food 4>"],
      "mindEaseRecommendation": "<Wellness/stress management priority guidelines>",
      "recommendedMindEaseMinutes": 120,
      "hairInsightRecommendation": "<Scalp care and routine focus guidelines>",
      "recommendedHairCareRoutine": "<Detailed step-by-step wash and oiling pattern>",
      "dailyPlans": [
        {
          "dayNumber": 1,
          "dayName": "Day 1",
          "eat": "Diet recommendations summary for today",
          "eatActions": [
            { "title": "Oatmeal & Almonds", "subtitle": "High in biotin and healthy fats", "time": "Breakfast" },
            { "title": "Lentil & Spinach Bowl", "subtitle": "Plant-based iron & zinc boost", "time": "Lunch" }
          ],
          "mindEase": "MindEase recommendations summary for today",
          "mindEaseActions": [
            { "title": "Deep Breathing", "subtitle": "Lowers cortisol", "time": "Evening" }
          ],
          "hairCare": "Hair routine details summary for today",
          "hairCareActions": [
            { "title": "Warm Coconut Oil Massage", "subtitle": "Stimulates follicles", "time": "Night" },
            { "title": "Sulfate-free Wash", "subtitle": "Gentle cleanse", "time": "Night" }
          ]
        },
        {
          "dayNumber": 2,
          "dayName": "Day 2",
          "eat": "Diet recommendations summary for today",
          "eatActions": [],
          "mindEase": "MindEase recommendations summary for today",
          "mindEaseActions": [],
          "hairCare": "Hair routine details summary for today",
          "hairCareActions": []
        },
        {
          "dayNumber": 3,
          "dayName": "Day 3",
          "eat": "Diet recommendations summary for today",
          "eatActions": [],
          "mindEase": "MindEase recommendations summary for today",
          "mindEaseActions": [],
          "hairCare": "Hair routine details summary for today",
          "hairCareActions": []
        },
        {
          "dayNumber": 4,
          "dayName": "Day 4",
          "eat": "Diet recommendations summary for today",
          "eatActions": [],
          "mindEase": "MindEase recommendations summary for today",
          "mindEaseActions": [],
          "hairCare": "Hair routine details summary for today",
          "hairCareActions": []
        },
        {
          "dayNumber": 5,
          "dayName": "Day 5",
          "eat": "Diet recommendations summary for today",
          "eatActions": [],
          "mindEase": "MindEase recommendations summary for today",
          "mindEaseActions": [],
          "hairCare": "Hair routine details summary for today",
          "hairCareActions": []
        },
        {
          "dayNumber": 6,
          "dayName": "Day 6",
          "eat": "Diet recommendations summary for today",
          "eatActions": [],
          "mindEase": "MindEase recommendations summary for today",
          "mindEaseActions": [],
          "hairCare": "Hair routine details summary for today",
          "hairCareActions": []
        },
        {
          "dayNumber": 7,
          "dayName": "Day 7",
          "eat": "Diet recommendations summary for today",
          "eatActions": [],
          "mindEase": "MindEase recommendations summary for today",
          "mindEaseActions": [],
          "hairCare": "Hair routine details summary for today",
          "hairCareActions": []
        }
      ]
    }
    """
    
    func generateWeeklyPlan(
        age: Int,
        heightCm: Float,
        weightKg: Float,
        activityLevel: String,
        hairFallStage: String,
        scalpCondition: String,
        hairDensity: String,
        hairType: String,
        answers: [String: String]
    ) async throws -> AIWeeklyPlan {
        
        var answersSummary = ""
        for (question, answer) in answers {
            answersSummary += "- Question: \(question)\n  Answer: \(answer)\n"
        }
        
        let userPrompt = """
        Analyze these profile parameters and generate a personalized 1-week hair plan:
        
        PROFILE:
        - Age: \(age)
        - Height: \(heightCm) cm
        - Weight: \(weightKg) kg
        - Activity Level: \(activityLevel)
        
        HAIR ANALYSIS:
        - Hair Loss Stage: \(hairFallStage)
        - Scalp Condition: \(scalpCondition)
        - Hair Density Level: \(hairDensity)
        - Hair Type: \(hairType)
        
        LIFESTYLE ASSESSMENT ANSWERS:
        \(answersSummary)
        
        Generate the JSON plan details exactly as specified.
        """
        
        let body: [String: Any] = [
            "model": "openrouter/auto",
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": userPrompt
                ]
            ]
        ]
        
        var request = URLRequest(url: URL(string: apiURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("https://hairanalysis.app", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("HairAnalysisTest", forHTTPHeaderField: "X-Title")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        let rawString = String(data: data, encoding: .utf8) ?? "nil"
        print("RAW AI RESPONSE: \(rawString)")
        
        guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = response["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let text = message["content"] as? String else {
            throw NSError(domain: "AIRecommendationService", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not parse AI response: \(rawString)"])
        }
        
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstBrace = cleaned.firstIndex(of: "{"),
           let lastBrace = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[firstBrace...lastBrace])
        }
        
        guard let jsonData = cleaned.data(using: .utf8) else {
            throw NSError(domain: "AIRecommendationService", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Could not convert cleaned text to data"])
        }
        
        do {
            let result = try JSONDecoder().decode(AIWeeklyPlan.self, from: jsonData)
            return result
        } catch {
            print("AI DECODE ERROR: \(error)")
            print("FAILED AI JSON: \(cleaned)")
            throw error
        }
    }
}
