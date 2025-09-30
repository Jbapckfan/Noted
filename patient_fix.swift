struct Patient: Identifiable, Codable {
    let id: UUID
    let medicalRecordNumber: String
    let firstName: String
    let lastName: String
    let dateOfBirth: Date
    let gender: String
    let primaryInsurance: String?
    let emergencyContact: String?
    let allergies: [String]
    let medications: [String]
    let medicalHistory: [String]
    let chartLevel: ChartLevel
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    init(id: UUID = UUID(), medicalRecordNumber: String, firstName: String, lastName: String, dateOfBirth: Date, gender: String, primaryInsurance: String? = nil, emergencyContact: String? = nil, allergies: [String] = [], medications: [String] = [], medicalHistory: [String] = [], chartLevel: ChartLevel) {
        self.id = id
        self.medicalRecordNumber = medicalRecordNumber
        self.firstName = firstName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.gender = gender
        self.primaryInsurance = primaryInsurance
        self.emergencyContact = emergencyContact
        self.allergies = allergies
        self.medications = medications
        self.medicalHistory = medicalHistory
        self.chartLevel = chartLevel
    }
}