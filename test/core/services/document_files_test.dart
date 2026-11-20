import 'package:calligro_app/core/services/document_files.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const pdfUrl =
      'https://firebasestorage.googleapis.com/v0/b/x.appspot.com/o/course_submissions%2Fc1%2Fa1%2Fs1_My%20Work.pdf?alt=media&token=t';
  const imageUrl = 'https://firebasestorage.googleapis.com/v0/b/x.appspot.com/o/course_submissions%2Fc1%2Fa1%2Fs1_photo.jpg?alt=media';

  test('a PDF is recognised by its name or by its link', () {
    expect(DocumentFiles.isPdf('My Work.pdf', imageUrl), isTrue);
    expect(DocumentFiles.isPdf('submission_file', pdfUrl), isTrue);
    expect(DocumentFiles.isPdf('WORK.PDF', ''), isTrue);
    expect(DocumentFiles.isPdf('photo.jpg', imageUrl), isFalse);
    expect(DocumentFiles.isPdf('notes.docx', 'https://x/o/notes.docx?alt=media'), isFalse);
  });

  test('the saved name keeps the file type, even when the name was lost', () {
    expect(DocumentFiles.downloadName('My Work.pdf', pdfUrl), 'My Work.pdf');
    expect(DocumentFiles.downloadName('submission_file', pdfUrl), 's1_My Work.pdf');
    expect(DocumentFiles.downloadName('', pdfUrl), 's1_My Work.pdf');
    expect(DocumentFiles.downloadName('Homework', pdfUrl), 'Homework.pdf');
    expect(DocumentFiles.downloadName('notes.docx', 'https://x/o/notes.docx?alt=media'), 'notes.docx');
  });
}
