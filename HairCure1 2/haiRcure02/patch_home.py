#import re
#
#with open('/Users/chetankandpal/Documents/HairCare/HairCure1 2/haiRcure02/HairCure/Views/Home/HomeView.swift', 'r') as f:
#    content = f.read()
#
## 1. Replace heroCardHeight
#content = re.sub(
#    r'private let heroCardHeight: CGFloat = 218',
#    r'private let heroCardHeight: CGFloat = 190',
#    content
#)
#
## 2. Replace HomeHairHealthCardView and HomeAICoachCardView
#new_cards = """struct HomeHairHealthCardView: View {
#    var viewModel: HomeViewModel
#    var store: AppDataStore
#    
#    var body: some View {
#        let report = store.latestScanReport
#        let plan = store.activePlan
#        let hasReport = report != nil
#        let density   = report?.hairDensityPercent ?? 0
#        let stage     = report?.hairFallStage.intValue ?? plan?.stage ?? 2
#        
#        let (severityLabel, severityColor): (String, Color) = {
#            switch stage {
#            case 1: return ("Healthy",  Color(red: 0.22, green: 0.78, blue: 0.45))
#            case 2: return ("Moderate", Color(red: 1.00, green: 0.60, blue: 0.15))
#            case 3: return ("Severe",   Color(red: 0.95, green: 0.32, blue: 0.22))
#            default: return ("Critical", Color(red: 0.85, green: 0.15, blue: 0.15))
#            }
#        }()
#        
#        return VStack(alignment: .leading, spacing: 16) {
#            HStack(alignment: .top) {
#                VStack(alignment: .leading, spacing: 4) {
#                    Text("Hair Health")
#                        .font(.system(size: 20, weight: .bold))
#                        .foregroundStyle(.primary)
#                    Text("Stage \(stage) • \(severityLabel)")
#                        .font(.system(size: 14, weight: .medium))
#                        .foregroundStyle(severityColor)
#                }
#                Spacer()
#                
#                VStack(alignment: .trailing, spacing: 2) {
#                    HStack(alignment: .firstTextBaseline, spacing: 2) {
#                        Text(hasReport ? "\(Int(density))" : "--")
#                            .font(.system(size: 36, weight: .bold, design: .rounded))
#                            .foregroundStyle(.primary)
#                        Text("%")
#                            .font(.system(size: 18, weight: .bold, design: .rounded))
#                            .foregroundStyle(.secondary)
#                    }
#                    Text("Density")
#                        .font(.system(size: 13, weight: .medium))
#                        .foregroundStyle(.secondary)
#                }
#            }
#            
#            Spacer(minLength: 0)
#            
#            Button {
#                viewModel.pushHairProgress = true
#            } label: {
#                HStack {
#                    Text("View Progress")
#                        .font(.system(size: 15, weight: .semibold))
#                        .foregroundStyle(Color.hcBrown)
#                    Spacer()
#                    Image(systemName: "arrow.right")
#                        .font(.system(size: 14, weight: .bold))
#                        .foregroundStyle(Color.hcBrown)
#                }
#                .padding(.vertical, 14)
#                .padding(.horizontal, 16)
#                .background(Color.hcBrown.opacity(0.1))
#                .clipShape(RoundedRectangle(cornerRadius: 14))
#            }
#            .buttonStyle(.plain)
#        }
#        .padding(20)
#        .frame(height: heroCardHeight)
#        .background(Color.white)
#        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
#        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
#    }
#}
#
#struct HomeAICoachCardView: View {
#    var viewModel: HomeViewModel
#    
#    var body: some View {
#        VStack(alignment: .leading, spacing: 16) {
#            HStack(alignment: .top) {
#                VStack(alignment: .leading, spacing: 8) {
#                    HStack(spacing: 6) {
#                        Image(systemName: "sparkles")
#                            .font(.system(size: 12, weight: .bold))
#                            .foregroundStyle(Color.hcBrown)
#                        Text("AI POWERED")
#                            .font(.system(size: 11, weight: .bold))
#                            .foregroundStyle(Color.hcBrown)
#                            .kerning(1.2)
#                    }
#                    Text("Hair Coach")
#                        .font(.system(size: 20, weight: .bold))
#                        .foregroundStyle(.primary)
#                    Text("Personalised guidance for your hair journey, anytime.")
#                        .font(.system(size: 14))
#                        .foregroundStyle(.secondary)
#                        .lineSpacing(2)
#                }
#                Spacer(minLength: 16)
#                ZStack {
#                    Circle()
#                        .fill(Color.hcBrown.opacity(0.1))
#                        .frame(width: 52, height: 52)
#                    Image(systemName: "brain.head.profile")
#                        .font(.system(size: 22, weight: .medium))
#                        .foregroundStyle(Color.hcBrown)
#                }
#            }
#            
#            Spacer(minLength: 0)
#            
#            Button { viewModel.showCoach = true } label: {
#                HStack {
#                    Text("Start Session")
#                        .font(.system(size: 15, weight: .semibold))
#                        .foregroundStyle(.white)
#                    Spacer()
#                    Image(systemName: "arrow.right")
#                        .font(.system(size: 14, weight: .bold))
#                        .foregroundStyle(.white)
#                }
#                .padding(.vertical, 14)
#                .padding(.horizontal, 16)
#                .background(Color.hcBrown)
#                .clipShape(RoundedRectangle(cornerRadius: 14))
#            }
#            .buttonStyle(.plain)
#        }
#        .padding(20)
#        .frame(height: heroCardHeight)
#        .background(Color.white)
#        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
#        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
#    }
#}"""
#
## Use regex to find and replace both structs
#pattern = re.compile(
#    r'struct HomeHairHealthCardView: View \{.*?(?=struct HomeFeatureCardsSectionView: View \{)',
#    re.DOTALL
#)
#
#content = pattern.sub(new_cards + "\n\n", content)
#
#with open('/Users/chetankandpal/Documents/HairCare/HairCure1 2/haiRcure02/HairCure/Views/Home/HomeView.swift', 'w') as f:
#    f.write(content)
#
#print("Done")
