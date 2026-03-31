
import SwiftUI

struct DayHomeHeaderView: View {
    var body: some View {
        HStack {
            Text("Passbook")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.charcoal)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
        .padding(.top, 12)
    }
}

#Preview {
    DayHomeHeaderView()
        .background(AppColors.homeBlue)
}
